import {defineConfig} from '@playwright/test';
import base from './playwright.config';
export default defineConfig({...base,testMatch:'upstream-ui.spec.ts',workers:1,timeout:90000,use:{...base.use,baseURL:'http://127.0.0.1:5181',trace:'retain-on-failure'},webServer:{command:'node node_modules/vite/bin/vite.js preview --host 127.0.0.1 --port 5181',url:'http://127.0.0.1:5181',reuseExistingServer:true}});
