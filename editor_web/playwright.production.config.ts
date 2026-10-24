import {defineConfig} from '@playwright/test';
import base from './playwright.config';
export default defineConfig({...base,webServer:{command:'node node_modules/vite/bin/vite.js preview --host 127.0.0.1 --port 5179',url:'http://127.0.0.1:5179',reuseExistingServer:process.env.PLAYWRIGHT_REUSE_SERVER==='1'}});
