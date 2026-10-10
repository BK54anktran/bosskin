(function(){
  // Phóng to ảnh
  var lb=document.getElementById('lightbox'), lbi=lb.querySelector('img');
  document.querySelectorAll('a.zoom').forEach(function(a){a.addEventListener('click',function(e){e.preventDefault();lbi.src=a.getAttribute('href');lb.hidden=false;});});
  lb.addEventListener('click',function(){lb.hidden=true;lbi.src='';});
  document.addEventListener('keydown',function(e){if(e.key==='Escape'){lb.hidden=true;document.body.classList.remove('nav-open');}});
  // Tìm kiếm (bỏ dấu)
  var norm=function(s){return (s||'').toLowerCase().replace(/đ/g,'d').normalize('NFD').replace(/[̀-ͯ]/g,'');};
  var idx=(window.HELP_INDEX||[]).map(function(r){return Object.assign({n:norm(r.t+' '+r.p+' '+r.x),nt:norm(r.t)},r);});
  var q=document.getElementById('q'), box=document.getElementById('results'), sel=-1;
  function render(){
    var v=norm(q.value.trim()); sel=-1;
    if(!v){box.style.display='none';return;}
    var words=v.split(/\s+/);
    var hits=idx.filter(function(r){return words.every(function(w){return r.n.indexOf(w)>=0;});})
      .sort(function(a,b){return (b.nt.indexOf(v)>=0)-(a.nt.indexOf(v)>=0);}).slice(0,12);
    box.innerHTML=hits.length?hits.map(function(r){return '<a href="'+r.u+'">'+r.t+'<small>'+r.p+'</small></a>';}).join(''):'<a>Không tìm thấy — thử từ khác</a>';
    box.style.display='block';
  }
  q.addEventListener('input',render);
  q.addEventListener('keydown',function(e){
    var as=box.querySelectorAll('a[href]'); if(!as.length) return;
    if(e.key==='ArrowDown'){sel=Math.min(sel+1,as.length-1);} else if(e.key==='ArrowUp'){sel=Math.max(sel-1,0);} else if(e.key==='Enter'){location.href=as[Math.max(sel,0)].getAttribute('href');return;} else return;
    e.preventDefault(); as.forEach(function(a,i){a.classList.toggle('sel',i===sel);});
  });
  document.addEventListener('click',function(e){if(!e.target.closest('.search')) box.style.display='none';});
  document.addEventListener('keydown',function(e){if(e.key==='/'&&document.activeElement!==q){e.preventDefault();q.focus();}});
})();

// Mục lục bên phải: tô mục đang đọc
(function(){
  var links=[].slice.call(document.querySelectorAll('.toc-side a'));
  if(!links.length||!('IntersectionObserver' in window))return;
  var map={};links.forEach(function(a){map[a.getAttribute('href').slice(1)]=a;});
  var io=new IntersectionObserver(function(es){es.forEach(function(e){if(e.isIntersecting){links.forEach(function(a){a.classList.remove('on');});var a=map[e.target.id];if(a)a.classList.add('on');}});},{rootMargin:'-70px 0px -70% 0px'});
  Object.keys(map).forEach(function(id){var h=document.getElementById(id);if(h)io.observe(h);});
})();

// Cấu hình chung với trang giới thiệu (../site-config.js): nút Đăng nhập, liên hệ, mạng xã hội
(function(){
  var cfg=window.BOSSKIN||{}, u=cfg.appUrl;
  document.querySelectorAll('.js-app').forEach(function(a){if(u){a.href=u;a.hidden=false;}});
  document.querySelectorAll('.js-app-row').forEach(function(r){r.hidden=!u;});
  document.querySelectorAll('.js-yr').forEach(function(s){s.textContent=new Date().getFullYear();});
  // Chân trang: điện thoại / Zalo / email / mạng xã hội theo site-config.js; trống thì ẩn
  function setContact(sel, text, href) { var li = document.querySelector(sel); if (!li || !text) return; var a = li.querySelector('a'); a.textContent = text; a.href = href; li.hidden = false; }
  var phoneDigits = String(cfg.contactPhone || '').replace(/[^0-9+]/g, '');
  setContact('.js-phone', cfg.contactPhone, 'tel:' + phoneDigits);
  setContact('.js-zalo', cfg.contactPhone && 'Zalo ' + cfg.contactPhone, 'https://zalo.me/' + phoneDigits);
  setContact('.js-mail', cfg.contactEmail, 'mailto:' + cfg.contactEmail);
  if (cfg.contactPhone || cfg.contactEmail) document.querySelector('.js-nocontact').hidden = true;
  var anySoc = false;
  document.querySelectorAll('.js-soc').forEach(function (a) { var u = cfg[a.dataset.key]; if (u) { a.href = u; a.hidden = false; anySoc = true; } });
  document.querySelectorAll('.socials').forEach(function (s) { s.hidden = !anySoc; });
})();
