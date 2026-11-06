// Basic consent mode. The stream must have all enhanced measurement disabled.
export function googleAnalytics({id, page, referrer, allowed, win = window, doc = document}) {
  let loading, generation = 0;
  const disableKey = 'ga-disable-' + id;
  win[disableKey] = true;
  function gtag() { win.dataLayer ||= []; win.dataLayer.push(arguments); }
  function load() {
    if (!loading) loading = new Promise(resolve => {
      const script = doc.createElement('script');
      script.async = true;
      script.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(id);
      script.referrerPolicy = 'no-referrer';
      script.onload = () => resolve(true);
      script.onerror = () => { script.remove(); loading = undefined; resolve(false); };
      doc.head.append(script);
    });
    return loading;
  }
  return {
    async start() {
      const token = ++generation;
      if (!id || !allowed()) return;
      gtag('consent','default',{analytics_storage:'granted',ad_storage:'denied',ad_user_data:'denied',ad_personalization:'denied'});
      if (!await load() || token !== generation || !allowed()) return;
      win[disableKey] = false;
      const context = {page_location:page,page_referrer:referrer,page_title:'NepType'};
      gtag('set',{...context,allow_google_signals:false,allow_ad_personalization_signals:false,ads_data_redaction:true,url_passthrough:false});
      gtag('js',new Date());
      gtag('config',id,{...context,send_page_view:false,allow_google_signals:false,allow_ad_personalization_signals:false,cookie_flags:'SameSite=Lax;Secure',linker:{accept_incoming:false}});
      gtag('event','page_view',{...context,send_to:id});
    },
    stop() {
      ++generation;
      win[disableKey] = true;
      for (const name of ['_ga','_ga_' + id.replace(/^G-/,'').replaceAll('-','_')]) {
        for (const domain of ['', '; domain=' + win.location.hostname, '; domain=.' + win.location.hostname]) {
          doc.cookie = name + '=; Max-Age=0; path=/' + domain + '; SameSite=Lax; Secure';
        }
      }
      // No denied-consent update, which could send cookieless pings.
    }
  };
}
