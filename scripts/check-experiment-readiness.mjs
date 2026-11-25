#!/usr/bin/env node
// Read-only gate. Never starts a test against the old live product page.
import {readFile,writeFile} from 'node:fs/promises';
import {fromEnv} from '/home/user/code/storepilot/src/apple.js';
for(const line of (await readFile('/home/user/.config/storepilot/server.env','utf8')).split('\n')){
 const i=line.indexOf('=');if(i>0)process.env[line.slice(0,i)]=line.slice(i+1);
}
const api=await fromEnv();
const app='6816529007';
const locales=Object.keys(JSON.parse(await readFile(new URL('../output/app-store-calm/localizations.json',import.meta.url))));
const versions=await api.list(`/v1/apps/${app}/appStoreVersions?limit=200`);
const target=versions.find(x=>x.attributes.versionString==='1.2');
const live=versions.find(x=>['READY_FOR_SALE','READY_FOR_DISTRIBUTION'].includes(x.attributes.appStoreState));
const reasons=[];
if(target&&!['READY_FOR_SALE','READY_FOR_DISTRIBUTION'].includes(target.attributes.appStoreState))reasons.push(`Version 1.2 is ${target.attributes.appStoreState}.`);
if(live?.attributes.versionString!=='1.2') reasons.push(`Live version is ${live?.attributes.versionString??'none'}; requires 1.2.`);
const liveLocales=live?await api.list(`/v1/appStoreVersions/${live.id}/appStoreVersionLocalizations?limit=200`):[];
const missing=locales.filter(l=>!liveLocales.some(x=>x.attributes.locale===l));
if(missing.length)reasons.push(`Live page is missing ${missing.length} required locales.`);
const experiments=await api.list(`/v1/apps/${app}/appStoreVersionExperimentsV2?limit=200`);
const draft=experiments.filter(x=>x.attributes.state==='PREPARE_FOR_SUBMISSION');
if(draft.length)reasons.push(`Existing draft(s) preserved: ${draft.map(x=>x.attributes.name).join(', ')}. Choose a draft for the test before staging.`);
reasons.push('Before launch: verify Calm original image hashes, stage Charles as the only treatment, verify all 49 locale screenshot orders and search covers, obtain Apple asset review approval, and set total treatment traffic to 50%.');
const report={checkedAt:new Date().toISOString(),ready:false,liveVersion:live?.attributes.versionString,targetVersionState:target?.attributes.appStoreState,allocation:{originalCalm:50,treatmentCharles:50},locales:locales.length,excluded:['he'],reasons};
console.log(JSON.stringify(report,null,2));
