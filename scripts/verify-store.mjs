// Read back Apple's current state and compare all localized text and artwork hashes.
import {readFile,writeFile} from 'node:fs/promises';
import {resolve,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const assets=resolve(root,'output/app-store-calm');
const {fromEnv}=await import(pathToFileURL(resolve(process.env.STOREPILOT_SOURCE||'/home/user/code/storepilot','src/apple.js')));
try{for(const line of (await readFile(process.env.STOREPILOT_ENV||'/home/user/.config/storepilot/server.env','utf8')).split('\n')){const i=line.indexOf('=');if(i>0&&!process.env[line.slice(0,i)])process.env[line.slice(0,i)]=line.slice(i+1);}}catch(e){if(e.code!=='ENOENT')throw e;}
const a=await fromEnv();const versionId='ff701b94-3740-4e90-bf28-162d049a4e0c';
const expected=JSON.parse(await readFile(resolve(assets,'localizations.json'),'utf8'));
const locales=await a.list(`/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations?limit=200`);
const infos=await a.list('/v1/appInfos/d06a7211-6eed-4e0b-a08e-5df40e24b03f/appInfoLocalizations?limit=200');
const version=(await a.request(`/v1/appStoreVersions/${versionId}`)).data;
const errors=[];const results={};
if(locales.length!==49||locales.some(l=>l.attributes.locale==='he'))errors.push('Expected exactly 49 version locales excluding Hebrew');
if(infos.length!==49||infos.some(l=>l.attributes.locale==='he'))errors.push('Expected exactly 49 App Info locales excluding Hebrew');
const ref=async path=>'advoid-calm-v4-'+createHash('sha256').update(await readFile(path)).digest('hex');
let cursor=0;const entries=Object.entries(expected);
async function worker(){while(cursor<entries.length){const [locale,e]=entries[cursor++];try{
 const l=locales.find(l=>l.attributes.locale===locale);if(!l)throw Error('Localization missing');
 for(const key of ['description','keywords','whatsNew'])if(l.attributes[key]!==e[key])throw Error(`Text mismatch: ${key}`);
 if(l.attributes.promotionalText!==e.subtitle)throw Error('Promotional text mismatch');
 const info=infos.find(l=>l.attributes.locale===locale);if(info?.attributes.subtitle!==e.subtitle)throw Error('Subtitle mismatch');
 const response=await a.request(`/v1/appStoreVersionLocalizations/${l.id}/placements?include=image&sort=placementGroupPosition&limit=200`);
 const placements=response.data;const images=new Map((response.included||[]).map(i=>[i.id,i]));
 const screenshots=placements.filter(p=>p.attributes.placementType==='APP_SCREENSHOT'&&p.attributes.placementGroup==='IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE');
 const search=placements.filter(p=>p.attributes.placementType==='APP_STORE_SEARCH_RESULTS_ASSET');
 if(screenshots.length!==3||search.length!==1)throw Error(`Unexpected media counts: ${screenshots.length} screenshots, ${search.length} search cards`);
 const stale=placements.filter(p=>p.attributes.placementType==='APP_SCREENSHOT'&&p.attributes.placementGroup!=='IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE');if(stale.length)throw Error('Stale size-specific screenshots remain');
 const paths=['01-home.png','02-activity.png','03-settings.png'].map(name=>resolve(assets,'screenshots-v3',locale,name));paths.push(resolve(assets,'search-cards',locale+'.png'));
 for(const [i,p] of [...screenshots,...search].entries()){
  const image=images.get(p.relationships.image?.data?.id);if(!image)throw Error('Image relationship not included');
  if(image.attributes.referenceName!==await ref(paths[i]))throw Error('Artwork hash or screenshot order mismatch');
  if(!['PREPARE_FOR_SUBMISSION','APPROVED'].includes(image.attributes.state))throw Error(`Image not ready: ${image.attributes.state}`);
 }
 results[locale]={text:'verified',subtitle:'verified',screenshots:3,searchCards:1,frame:'Dynamic Island v4',imagesReady:true};
 }catch(e){errors.push({locale,error:e.message});}}
}
await Promise.all([worker(),worker(),worker()]);
const report={verifiedAt:new Date().toISOString(),version:version.attributes.versionString,state:version.attributes.appStoreState,locales:results,errors};
await writeFile('/home/user/.local/share/storepilot/advoid-backups/verification.json',JSON.stringify(report,null,2),{mode:0o600});
console.log(JSON.stringify({version:report.version,state:report.state,verifiedLocales:Object.keys(results).length,screenshots:Object.keys(results).length*3,searchCards:Object.keys(results).length,errors},null,2));
if(errors.length)process.exitCode=1;
