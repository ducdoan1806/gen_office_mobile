import {test,expect} from '@playwright/test';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
for(const success of [true,false]) test(`OAuth callback mobile ${success?'success countdown':'error'}`,async({page})=>{
 const result=spawnSync(process.env.DART_EXECUTABLE||'dart',[fileURLToPath(new URL('../../tool/render_oauth_return.dart',import.meta.url)),...(success?[]:['--error'])],{encoding:'utf8'});
 expect(result.status,result.stderr).toBe(0);
 await page.setViewportSize({width:360,height:640});
 await page.route('**/qa-oauth',route=>route.fulfill({contentType:'text/html',body:result.stdout,headers:{'Content-Security-Policy':"default-src 'none'; style-src 'nonce-qa-page-nonce'; script-src 'nonce-qa-page-nonce'; base-uri 'none'; frame-ancestors 'none'"}}));
 await page.goto('/qa-oauth');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 const back=page.getByRole('link',{name:'Quay lại VPIC1 Office'});
 if(success){
  await expect(back).toBeHidden();
  await page.waitForTimeout(4000);await expect(back).toBeHidden();
  await expect(back).toBeVisible({timeout:2000});
 } else {
  await expect(page.getByRole('heading')).toHaveText('Chưa hoàn tất đăng nhập');
  await expect(back).toBeVisible();
 }
 await page.screenshot({path:test.info().outputPath(`oauth-${success?'success':'error'}.png`)});
});
