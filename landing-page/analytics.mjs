import posthog from 'posthog-js';
import {readConsent,consentKey,legacyOptOutKey,analyticsPage,analyticsReferrer,safeEvents,coarseProperties} from './analytics-policy.mjs';
import {googleAnalytics} from './google-analytics.mjs';
const key=__POSTHOG_KEY__,host=__POSTHOG_HOST__,gaId=__GA_MEASUREMENT_ID__;
const privacySignal=navigator.doNotTrack==='1'||navigator.globalPrivacyControl===true;
const test=new URLSearchParams(location.search).get('analytics_test')==='1';
const configured=__PRODUCTION__&&Boolean((key&&host)||gaId);
let storage;
try{storage=window.localStorage;}catch{storage={getItem:()=>null,setItem(){},removeItem(){}};}
let consent=readConsent(storage),ready=false,initialized=false;
const allowed=()=>configured&&!test&&!privacySignal&&consent!=='denied';
const page=analyticsPage(location.href,__PUBLIC_PATHS__),referrer=analyticsReferrer(document.referrer);
const google=googleAnalytics({id:gaId,page,referrer,allowed});
function capture(event,input={}) {
  if(!ready||!allowed()||!safeEvents.has(event))return;
  posthog.capture(event,{app:'neptype',language:document.documentElement.lang,is_test:false,...coarseProperties(input)},{transport:'sendBeacon',send_instantly:true});
}
window.NepTypeAnalytics={capture};
function start() {
  if(!allowed())return;
  if(key&&host){
    if(!initialized){
      posthog.init(key,{
        api_host:host,autocapture:false,capture_pageview:false,capture_pageleave:false,
        capture_dead_clicks:false,capture_performance:false,disable_session_recording:true,
        disable_surveys:true,advanced_disable_flags:true,person_profiles:'identified_only',
        persistence:'memory',respect_dnt:true,save_campaign_params:false,save_referrer:false,
        disable_capture_url_hashes:true,disable_external_dependency_loading:true,request_batching:false,
        before_send(event){
          if(!allowed()||!event||!safeEvents.has(event.event))return null;
          const original=event.properties||{};
          event.properties={token:key,app:'neptype',language:document.documentElement.lang,is_test:false,...coarseProperties(original),
            $current_url:page,$referrer:referrer,$process_person_profile:false,
            ...Object.fromEntries(['distinct_id','$browser','$browser_version','$os','$device_type','$lib','$lib_version'].filter(name=>original[name]!==undefined).map(name=>[name,original[name]]))};
          return {event:event.event,uuid:event.uuid,timestamp:event.timestamp,properties:event.properties};
        }
      });
      initialized=true;
    }else posthog.opt_in_capturing({captureEventName:false});
    ready=true;capture('neptype_pageview');
  }
  void google.start();
}
function stop(){ready=false;google.stop();if(initialized)posthog.opt_out_capturing();}
function choose(value){
  consent=value;
  try{storage.setItem(consentKey,value);if(value==='granted')storage.removeItem(legacyOptOutKey);else storage.setItem(legacyOptOutKey,'true');}catch{/* Choice applies to this page if storage is unavailable. */}
  if(allowed())start();else stop();update();
}
const ne=document.documentElement.lang==='ne';
const copy=ne?{
  text:'Google Analytics र PostHog ले पृष्ठ भ्रमण र सुविधाको प्रयोग गन्छन्। तपाईंले लेखेको पाठ वा क्लिपबोर्ड पठाउँदैनौँ। एनालिटिक्स बन्द गरे पनि टाइपिङ चल्छ।',
  allow:'एनालिटिक्स सक्रिय गर्नुहोस्',settings:'एनालिटिक्स सेटिङ',revoke:'एनालिटिक्स बन्द गर्नुहोस्',close:'बन्द गर्नुहोस्',privacy:'गोपनीयता नीति',
  on:'यस ब्राउजरमा वेबसाइट एनालिटिक्स सक्रिय छ।',off:'यस ब्राउजरमा वेबसाइट एनालिटिक्स बन्द छ।',signal:'तपाईंको ब्राउजरको गोपनीयता संकेतका कारण एनालिटिक्स बन्द छ।'
}:{
  text:'Google Analytics and PostHog count page visits and feature use. We do not send your typed text or clipboard contents. Typing works with analytics turned off.',
  allow:'Turn on analytics',settings:'Analytics settings',revoke:'Turn off analytics',close:'Close',privacy:'Privacy policy',on:'Website analytics is on in this browser.',off:'Website analytics is off in this browser.',signal:'Analytics is off because of your browser privacy signal.'
};
let dialog,state;
function update(){
  if(!dialog)return;
  state.textContent=privacySignal?copy.signal:allowed()?copy.on:copy.off;
  dialog.querySelector('[data-choice="granted"]').disabled=privacySignal;
  dialog.querySelector('[data-choice="granted"]').hidden=allowed();
  dialog.querySelector('[data-revoke]').hidden=!allowed();
}
if(configured&&!test){
  const privacy=(ne?'/ne':'')+'/privacy/#analytics';
  dialog=document.createElement('dialog');dialog.className='analytics-dialog';dialog.setAttribute('aria-labelledby','analytics-settings-title');
  dialog.innerHTML=`<h2 id="analytics-settings-title">${copy.settings}</h2><p data-state role="status"></p><p>${copy.text} <a href="${privacy}">${copy.privacy}</a></p><div class="analytics-actions"><button type="button" class="button" data-choice="granted">${copy.allow}</button><button type="button" class="button" data-revoke>${copy.revoke}</button><button type="button" class="button" data-close>${copy.close}</button></div>`;
  document.body.append(dialog);state=dialog.querySelector('[data-state]');
  dialog.addEventListener('keydown',event=>{
    if(event.key!=='Tab')return;
    const controls=[...dialog.querySelectorAll('a[href],button:not([disabled])')].filter(el=>!el.hidden&&el.getClientRects().length);
    const first=controls[0],last=controls.at(-1),active=document.activeElement;
    if(!first)return;
    if(!dialog.contains(active)||(event.shiftKey&&active===first)||(!event.shiftKey&&active===last)){
      event.preventDefault();(event.shiftKey?last:first).focus();
    }
  });
  dialog.addEventListener('click',event=>{
    const choice=event.target.closest('[data-choice]');
    if(choice){
      choose(choice.dataset.choice);dialog.close();
    }
    if(event.target.closest('[data-revoke]')){choose('denied');dialog.close();}
    if(event.target.closest('[data-close]'))dialog.close();
  });
  const settings=document.createElement('button');settings.type='button';settings.className='analytics-settings-link';settings.textContent=copy.settings;
  settings.addEventListener('click',()=>{update();dialog.showModal();});document.querySelector('footer .footer-brand')?.append(settings);
  const toggle=document.getElementById('analytics-toggle');
  if(toggle){toggle.textContent=copy.settings;toggle.hidden=false;toggle.addEventListener('click',()=>{update();dialog.showModal();});}
  update();
}
document.addEventListener('click',event=>{
  const link=event.target.closest('a[data-analytics-event]');
  if(link)capture(link.dataset.analyticsEvent,{placement:link.dataset.placement||'page',platform:link.dataset.platform||'macOS'});
});
window.addEventListener('storage',event=>{
  if([consentKey,legacyOptOutKey,null].includes(event.key)){
    const wasAllowed=allowed();consent=readConsent(storage);
    if(!allowed())stop();else if(!wasAllowed)start();update();
  }
});
start();
