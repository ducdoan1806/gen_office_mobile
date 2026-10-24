import { defineConfig } from '@playwright/test';
export default defineConfig({
 testDir: './e2e',
 use: { baseURL: 'http://127.0.0.1:5179', launchOptions: { executablePath: process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' } },
 webServer: {command:'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 5179',url:'http://127.0.0.1:5179',reuseExistingServer:false},
});
