import asyncio
import io
import json
from pathlib import Path
import tempfile
import unittest
import uuid
from unittest.mock import patch

from aiohttp import FormData, web
from aiohttp.test_utils import TestClient, TestServer
from PIL import Image
from server import CONSENT, Comfy, Failure, Gateway, bind_workflow, clean_image, create_app


def photo():
    data = io.BytesIO()
    Image.new('RGB', (32, 48), 'blue').save(data, format='JPEG', exif=b'Exif\x00\x00private-metadata')
    return data.getvalue()


def workflow(count=2):
    graph = {str(i): {'class_type': 'LoadImage', 'inputs': {'image': '{{image_' + str(i+1) + '}}'}} for i in range(count)}
    graph['prompt'] = {'class_type': 'TextEncodeQwenImageEditPlus', 'inputs': {'prompt': '{{prompt}}'}}
    graph['output'] = {'class_type': 'SaveImage', 'inputs': {'filename_prefix': 'old', 'images': ['decode', 0]}}
    return graph


class FakeModel:
    def __init__(self):
        self.calls = []
        self.wait = None
        self.error = False

    async def ready(self):
        return True

    async def generate(self, *args):
        self.calls.append(args)
        if self.wait:
            await self.wait.wait()
        if self.error:
            raise Failure(504, 'Timed out')
        return photo()


class APITests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = str(Path(self.tmp.name) / 'jobs.sqlite3')
        self.model = FakeModel()
        self.settings = {'workflows': {'try-on-1': workflow(), 'cleanup': workflow(1)}}
        self.gateway = Gateway(self.settings, 'a' * 32, self.state, self.model)
        self.client = TestClient(TestServer(create_app(self.gateway)))
        await self.client.start_server()
        self.addAsyncCleanup(self.client.close)
        self.headers = {'Authorization': 'Test ' + 'a' * 32, 'X-Pyxis-Consent': CONSENT, 'Idempotency-Key': str(uuid.uuid4())}

    def form(self, categories=None, bad=False):
        form = FormData()
        form.add_field('person', b'bad' if bad else photo(), filename='person.jpg', content_type='image/jpeg')
        form.add_field('garment_1', photo(), filename='garment.jpg', content_type='image/jpeg')
        form.add_field('categories', json.dumps(categories or ['tops']))
        return form

    async def post(self, headers=None, form=None):
        return await self.client.post('/v1/try-on/generate', data=self.form() if form is None else form,
                                      headers=self.headers if headers is None else headers)

    async def test_configuration_names_actual_retention_and_workflow_limits(self):
        response = await self.client.get('/v1/try-on/config')
        config = await response.json()
        self.assertTrue(config['available'])
        self.assertEqual(config['retention'], 'temporary-local')
        self.assertEqual(config['supportedGarmentCounts'], [1])
        self.assertIsNone(config['productID'])

    async def test_auth_and_fresh_consent_required_before_generation(self):
        for headers, status in [({}, 401), ({**self.headers, 'X-Pyxis-Consent': 'try-on-xai-zdr-v1'}, 403),
                                ({**self.headers, 'Idempotency-Key': '../../bad'}, 400)]:
            response = await self.post(headers)
            self.assertEqual(response.status, status)
            self.assertEqual(response.headers['Cache-Control'], 'no-store')
        self.assertEqual(self.model.calls, [])

    async def test_rejects_bad_images_fields_and_categories_without_gpu_use(self):
        for form in [self.form(bad=True), self.form(categories=['invalid']), self.form(categories=[{}])]:
            response = await self.post(form=form)
            self.assertIn(response.status, [400, 415])
        form = self.form()
        form.add_field('person', photo(), filename='duplicate.jpg')
        self.assertEqual((await self.post(form=form)).status, 400)
        self.assertFalse(self.model.calls)

    async def test_generation_preserves_source_order_strips_metadata_and_replays(self):
        response = await self.post()
        self.assertEqual(response.status, 200)
        output = await response.read()
        self.assertEqual(response.headers['Content-Type'], 'image/jpeg')
        self.assertNotIn(b'private-metadata', output)
        self.assertEqual(self.model.calls[0][0], 'try-on-1')
        self.assertEqual(len(self.model.calls[0][1]), 2)
        self.assertNotIn(b'private-metadata', self.model.calls[0][1][0])
        self.assertIn('original person', self.model.calls[0][2])
        replay = await self.post()
        self.assertEqual(await replay.read(), output)
        self.assertEqual(len(self.model.calls), 1)
        self.gateway.replay.clear()
        expired = await self.post()
        self.assertEqual(expired.status, 409)
        self.assertEqual((await expired.json())['code'], 'pc_job_unrecoverable')

    async def test_restart_and_uncertain_failure_cannot_repeat_gpu_job(self):
        self.model.error = True
        self.assertEqual((await self.post()).status, 504)
        await self.client.close()
        self.gateway = Gateway(self.settings, 'a' * 32, self.state, self.model)
        self.client = TestClient(TestServer(create_app(self.gateway)))
        await self.client.start_server()
        self.addAsyncCleanup(self.client.close)
        self.assertEqual((await self.post()).status, 409)
        self.assertEqual(len(self.model.calls), 1)

    async def test_busy_pc_does_not_queue_more_work(self):
        self.model.wait = asyncio.Event()
        task = asyncio.create_task(self.post())
        while not self.model.calls:
            await asyncio.sleep(.01)
        second = await self.post(headers={**self.headers, 'Idempotency-Key': str(uuid.uuid4())})
        self.assertEqual(second.status, 409)
        self.model.wait.set()
        self.assertEqual((await task).status, 200)

    async def test_cleanup_is_available_to_explicitly_consented_api_clients(self):
        form = FormData()
        form.add_field('source', photo(), filename='source.jpg')
        response = await self.client.post('/v1/ai/garment-cleanup', headers=self.headers, data=form)
        self.assertEqual(response.status, 200)
        self.assertEqual(self.model.calls[0][0], 'cleanup')

    async def test_unsupported_workflow_does_not_submit(self):
        self.settings['workflows'].pop('try-on-1')
        self.assertEqual((await self.post()).status, 503)
        self.assertFalse(self.model.calls)

    async def test_oversized_body_rejected_before_model(self):
        with patch('server.MAX_REQUEST', 128):
            client = TestClient(TestServer(create_app(Gateway(self.settings, 'a'*32, ':memory:', self.model))))
        await client.start_server()
        try:
            response = await client.post('/v1/try-on/generate', data=self.form(), headers=self.headers)
            self.assertEqual(response.status, 413)
        finally:
            await client.close()
        self.assertFalse(self.model.calls)


class WorkflowTests(unittest.TestCase):
    def test_binding_is_copy_and_scopes_output(self):
        source = workflow()
        graph, outputs = bind_workflow(source, ['person.jpg', 'shirt.jpg'], 'dress person', 'job')
        self.assertEqual(graph['0']['inputs']['image'], 'person.jpg')
        self.assertEqual(graph['1']['inputs']['image'], 'shirt.jpg')
        self.assertEqual(graph['output']['inputs']['filename_prefix'], 'pyxis/job/preview')
        self.assertEqual(source['0']['inputs']['image'], '{{image_1}}')
        self.assertEqual(outputs, ['output'])

    def test_missing_references_previews_and_ui_exports_rejected(self):
        for graph in [workflow(1), {'nodes': []}, {**workflow(), 'preview': {'class_type': 'PreviewImage', 'inputs': {}}}]:
            with self.assertRaises(ValueError):
                bind_workflow(graph, ['person.jpg', 'shirt.jpg'], 'prompt', 'job')


class ComfyIntegrationTests(unittest.IsolatedAsyncioTestCase):
    async def test_real_http_adapter_reads_result_and_cleans_only_owned_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            job, prompt_id = str(uuid.uuid4()), str(uuid.uuid4())
            output = root / 'output' / 'pyxis' / job
            other = root / 'output' / 'unrelated.jpg'
            other.parent.mkdir(parents=True)
            other.write_bytes(photo())
            seen = []
            async def submit(request):
                data = await request.json()
                seen.append(data)
                self.assertTrue((root / 'input' / data['prompt']['0']['inputs']['image']).exists())
                output.mkdir(parents=True)
                (output / 'preview.jpg').write_bytes(photo())
                return web.json_response({'prompt_id': prompt_id})
            async def history(request):
                return web.json_response({prompt_id: {'status': {'status_str': 'success'}, 'outputs': {
                    'output': {'images': [{'type': 'output', 'subfolder': f'pyxis/{job}', 'filename': 'preview.jpg'}]}}}})
            async def delete(request):
                self.assertEqual(await request.json(), {'delete': [prompt_id]})
                return web.json_response({})
            app = web.Application()
            app.router.add_post('/prompt', submit)
            app.router.add_get('/history/{id}', history)
            app.router.add_post('/history', delete)
            server = TestServer(app)
            await server.start_server()
            try:
                model = Comfy({'root': root, 'port': server.port, 'workflows': {'try-on-1': workflow()}})
                result = await model.generate('try-on-1', [photo(), photo()], 'prompt', job)
                self.assertTrue(result.startswith(b'\xff\xd8'))
                self.assertFalse((root / 'input' / 'pyxis' / job).exists())
                self.assertFalse(output.exists())
                self.assertTrue(other.exists())
                self.assertEqual(len(seen), 1)
            finally:
                await server.close()
