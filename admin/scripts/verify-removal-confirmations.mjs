import { chromium } from 'playwright';
import { config } from 'dotenv';
import assert from 'node:assert/strict';
config({quiet:true});
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1440,height:900}});
let removals=0;
// Never delete live data during verification.
await page.route('**/api/unassign-trainer',route=>{removals++;return route.fulfill({status:500,contentType:'application/json',body:'{"error":"Test failure"}'});});
await page.route('**/api/delete-user',route=>{removals++;return route.fulfill({status:500,contentType:'application/json',body:'{"error":"Test failure"}'});});
try {
 await page.goto('http://127.0.0.1:5173/login');
 await page.locator('input[type=email]').fill(process.env.ADMIN_EMAIL);
 await page.locator('input[type=password]').fill(process.env.ADMIN_PASSWORD);
 await page.getByRole('button',{name:/sign in/i}).click();
 await page.waitForURL(url=>!url.pathname.includes('login'),{timeout:60000});
 await page.goto('http://127.0.0.1:5173/trainers');
 await page.getByRole('row').filter({has:page.getByText('John Paul',{exact:true})}).click();
 const availability=page.getByRole('heading',{name:'Availability',exact:true}).locator('..').locator('.grid p');
 await availability.first().waitFor();
 assert.deepEqual((await availability.allTextContents()).map(s=>s.split(' ')[0]),['Mon','Wed','Fri','Sat']);
 await page.getByRole('button',{name:'Remove assignment',exact:true}).first().click();
 const dialog=page.getByRole('dialog',{name:'Remove trainer assignment?'});
 await dialog.waitFor(); assert.equal(removals,0);
 await dialog.getByRole('button',{name:'Cancel',exact:true}).click();
 assert.equal(await dialog.count(),0); assert.equal(removals,0);
 await page.getByRole('button',{name:'Remove assignment',exact:true}).first().click();
 await dialog.getByRole('button',{name:'Remove assignment',exact:true}).click();
 await dialog.getByRole('alert').waitFor(); assert.equal(removals,1);
 await dialog.getByRole('button',{name:'Cancel',exact:true}).click();
 console.log('PASS saved availability only; assignment confirmation, cancel, and failure handling');
 for(const [route,button,title] of [['members','Delete member','Delete Member?'],['trainers','Delete trainer','Delete Trainer?']]) {
  await page.goto(`http://127.0.0.1:5173/${route}`);
  await page.getByRole('button',{name:button,exact:true}).first().click();
  await page.getByRole('heading',{name:title,exact:true}).waitFor();
  assert.equal(removals,1);
  await page.getByRole('button',{name:'Cancel',exact:true}).click();
  assert.equal(await page.getByRole('heading',{name:title,exact:true}).count(),0);
  assert.equal(removals,1);
  console.log('PASS',route,'trash requires confirmation; cancellation sends no request');
 }
} finally { await browser.close(); }
