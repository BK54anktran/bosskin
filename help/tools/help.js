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
