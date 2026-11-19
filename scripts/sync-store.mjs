// Synchronize approved AdVoid 1.2 artwork and localized text. Never submits a review.
// Run: node scripts/sync-store.mjs --apply (requires ASC_* or local private env file).
import {readFile,writeFile,mkdir,rename} from 'node:fs/promises';
import {resolve,dirname} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const assets=resolve(root,'output/app-store-calm');
const storepilot=process.env.STOREPILOT_SOURCE || '/home/user/code/storepilot';
const {fromEnv,relation}=await import(pathToFileURL(resolve(storepilot,'src/apple.js')));
const privateEnv=process.env.STOREPILOT_ENV || '/home/user/.config/storepilot/server.env';
try { for(const line of (await readFile(privateEnv,'utf8')).split('\n')){const i=line.indexOf('=');if(i>0&&!process.env[line.slice(0,i)])process.env[line.slice(0,i)]=line.slice(i+1);} }catch(e){if(e.code!=='ENOENT')throw e;}
const apple=await fromEnv();
const config=JSON.parse(await readFile(resolve(assets,'localizations.json'),'utf8'));
const appId='6816529007', versionId='ff701b94-3740-4e90-bf28-162d049a4e0c', infoId='d06a7211-6eed-4e0b-a08e-5df40e24b03f';
const stateDir=process.env.STOREPILOT_STATE || '/home/user/.local/share/storepilot/advoid-backups';await mkdir(stateDir,{recursive:true});
const report={startedAt:new Date().toISOString(),version:'1.2',locales:{},errors:[]};
const reportPath=resolve(stateDir,'sync-report.json');
let persistQueue=Promise.resolve();
const persist=()=>{const body=JSON.stringify(report,null,2);persistQueue=persistQueue.then(async()=>{const temp=reportPath+'.tmp';await writeFile(temp,body,{mode:0o600});await rename(temp,reportPath)});return persistQueue;};
const locales=await apple.list(`/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations?limit=200`);
const infos=await apple.list(`/v1/appInfos/${infoId}/appInfoLocalizations?limit=200`);
const version=(await apple.request(`/v1/appStoreVersions/${versionId}`)).data;
if(version.attributes.versionString!=='1.2'||!['DEVELOPER_REJECTED','PREPARE_FOR_SUBMISSION','REJECTED','METADATA_REJECTED'].includes(version.attributes.appStoreState))throw Error('Target version is not editable.');
if(Object.keys(config).length!==49||config.he)throw Error('Expected 49 locales without Hebrew.');
const groups=[['IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE','']];
const screenNames=['01-home.png','02-activity.png','03-settings.png'];
const filesFor=locale=>groups.map(([group,folder])=>({type:'APP_SCREENSHOT',group,files:screenNames.map(name=>resolve(assets,'screenshots-v3',locale,folder,name))})).concat([{type:'APP_STORE_SEARCH_RESULTS_ASSET',group:'DEFAULT_PROFILE',files:[resolve(assets,'search-cards',locale+'.png')]}]);
// Preflight every desired file and every string before changing anything.
for(const [locale,entry] of Object.entries(config)){
 for(const [field,max] of [['subtitle',30],['keywords',100],['description',4000],['whatsNew',4000]])if(typeof entry[field]!=='string'||[...entry[field]].length>max)throw Error(`${locale}: invalid ${field}`);
 for(const group of filesFor(locale))for(const file of group.files){const b=await readFile(file);if(b.length<1000||!b.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))throw Error('Invalid PNG: '+file);}
}
if(!process.argv.includes('--apply')) {console.log('Plan: update 49 locales, 3 highest-resolution iPhone screenshots (smaller sizes inherit), and a search creative per locale. Hebrew excluded. No writes.');process.exit(0);}
// Snapshot all touched surfaces immediately before mutation, preserving media relationships.
const backup={version,locales,infos,placements:{}};
for(const locale of locales){backup.placements[locale.attributes.locale]=await apple.list(`/v1/appStoreVersionLocalizations/${locale.id}/placements?include=image,video&limit=200`);}
const backupPath=resolve(stateDir,`before-${Date.now()}.json`);await writeFile(backupPath,JSON.stringify(backup,null,2),{mode:0o600});report.backup=backupPath;await persist();
const library=(await apple.request(`/v1/apps/${appId}/assetLibrary`)).data.id;
const images=await apple.list(`/v1/appAssetLibraries/${library}/images?limit=200`);
const pendingImages=new Map();
async function imageFor(file,category){
 const bytes=await readFile(file);const checksum=createHash('sha256').update(bytes).digest('hex');const ref=`advoid-calm-v3-${checksum}`;
 if(pendingImages.has(ref))return pendingImages.get(ref);
 const work=(async()=>{let image=images.find(i=>i.attributes.referenceName===ref&&['PREPARE_FOR_SUBMISSION','APPROVED'].includes(i.attributes.state));
  if(!image){image=await apple.upload(bytes,file.split('/').pop(),library,ref,category);images.push(image);}
  return image.id;})();pendingImages.set(ref,work);try{return await work}catch(e){pendingImages.delete(ref);throw e}
}
async function replaceGroup(localeId,group){
 const encoded=`filter[placementType]=${group.type}&filter[placementGroup]=${group.group}`;
 const old=await apple.list(`/v1/appStoreVersionLocalizations/${localeId}/placements?${encoded}&include=image&sort=placementGroupPosition&limit=200`);
 const desired=[];for(const file of group.files)desired.push(await imageFor(file,group.type==='APP_SCREENSHOT'?'APP_SCREENSHOTS_AND_PREVIEWS':'CREATIVE_ASSETS'));
 const oldImages=old.map(p=>p.relationships.image?.data?.id);
 if(JSON.stringify(oldImages)===JSON.stringify(desired))return 'unchanged';
 if(oldImages.some(id=>!id))throw Error('Existing placement missing image relationship; refusing to replace');
 const target=relation('appStoreVersionLocalizations',localeId);
 const place=async imageId=>(await apple.request('/v1/appAssetLibraryPlacements','POST',{type:'appAssetLibraryPlacements',attributes:{placementType:group.type,placementGroup:group.group},relationships:{image:relation('appAssetLibraryImages',imageId),appStoreVersionLocalization:target}})).data.id;
 const order=async ids=>{if(ids.length&&group.type==='APP_SCREENSHOT')await apple.request('/v1/appAssetLibraryPlacementOrderingRequests','POST',{type:'appAssetLibraryPlacementOrderingRequests',attributes:{placementGroup:group.group},relationships:{orderedPlacements:{data:ids.map(id=>({type:'appAssetLibraryPlacements',id}))},appStoreVersionLocalization:target}});};
 const removed=[],added=[];
 try{
  for(const p of old){await apple.request(`/v1/appAssetLibraryPlacements/${p.id}`,'DELETE');removed.push(p);}
  for(const id of desired)added.push(await place(id));await order(added);
 }catch(e){
  try{for(const id of added)await apple.request(`/v1/appAssetLibraryPlacements/${id}`,'DELETE');const restored=new Map();for(const p of removed)restored.set(p.id,await place(p.relationships.image.data.id));await order(old.map(p=>restored.get(p.id)||p.id));}
  catch(rollback){throw Error(`${e.message}; rollback failed: ${rollback.message}; see ${backupPath}`)}
  throw Error(`${e.message}; previous group restored`);
 }
 return 'updated';
}
async function syncLocale(locale,entry){
 const record=report.locales[locale]={state:'running',media:{}};await persist();
 try{
  let info=infos.find(l=>l.attributes.locale===locale);
  const name=info?.attributes.name || `AdVoid: ${entry.keywords.split(',')[0]}`;
  const infoAttrs={name:[...name].length<=30?name:'AdVoid',subtitle:entry.subtitle,privacyPolicyUrl:'https://roxuh.com/advoid/privacy'};
  const infoChanged=Object.entries(infoAttrs).some(([k,v])=>info?.attributes[k]!==v);
  if(!info||infoChanged){const data={type:'appInfoLocalizations',...(info?{id:info.id}:{}),attributes:{...infoAttrs,...(!info?{locale}:{})},...(!info?{relationships:{appInfo:relation('appInfos',infoId)}}:{})};info=(await apple.request(`/v1/appInfoLocalizations${info?'/'+info.id:''}`,info?'PATCH':'POST',data)).data;}
  let l=locales.find(l=>l.attributes.locale===locale);
  // Creating App Info may also create the version localization automatically.
  if(!l) l=(await apple.list(`/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations?limit=200`)).find(x=>x.attributes.locale===locale);
  const attrs={description:entry.description,keywords:entry.keywords,whatsNew:entry.whatsNew,supportUrl:'https://roxuh.com/advoid',marketingUrl:'https://roxuh.com/advoid',promotionalText:entry.subtitle};
  if(!l||Object.entries(attrs).some(([k,v])=>l.attributes[k]!==v)){const data={type:'appStoreVersionLocalizations',...(l?{id:l.id}:{}),attributes:{...attrs,...(!l?{locale}:{})},...(!l?{relationships:{appStoreVersion:relation('appStoreVersions',versionId)}}:{})};l=(await apple.request(`/v1/appStoreVersionLocalizations${l?'/'+l.id:''}`,l?'PATCH':'POST',data)).data;}
  record.localizationId=l.id;record.metadata='updated';await persist();
  for(const group of filesFor(locale)){record.media[group.type+':'+group.group]=await replaceGroup(l.id,group);await persist();}
  // Use Apple's scaling; stale overrides would show a different design on smaller phones.
  for(const group of ['IPHONE_FACE_ID_LARGE_PROFILE','IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE','IPAD_13_PROFILE']) record.media['APP_SCREENSHOT:'+group]=await replaceGroup(l.id,{type:'APP_SCREENSHOT',group,files:[]});
  record.state='complete';console.log(`${locale}: complete`);
 }catch(e){record.state='failed';record.error=e.message;report.errors.push({locale,error:e.message});console.error(`${locale}: ${e.message}`);}
 await persist();
}
const entries=Object.entries(config);let cursor=0;
async function worker(){while(cursor<entries.length){const [locale,entry]=entries[cursor++];await syncLocale(locale,entry);}}
// Separate localizations are independent; keep Apple load bounded.
await Promise.all(Array.from({length:4},worker));
report.finishedAt=new Date().toISOString();await persist();
console.log(JSON.stringify({complete:Object.values(report.locales).filter(l=>l.state==='complete').length,failed:report.errors.length,report:reportPath}));
if(report.errors.length)process.exitCode=1;
