/* Kagisho Connect | ASP.NET Core school website UI.
 * Every read/write is made through the same-origin ASP.NET Core API.
 * Accounts and staff administration use Supabase Auth and the school staff directory.
 * Classroom records are loaded from the same Supabase tables used by Flutter.
 */
(() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const esc = (v) => String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const csrf = document.querySelector('input[name="__RequestVerificationToken"]')?.value || '';
  const today = () => { const d=new Date(), off=d.getTimezoneOffset()*60000; return new Date(d.getTime()-off).toISOString().slice(0,10); };
  const dateLabel = (v) => v ? new Date(v.length === 10 ? `${v}T12:00:00` : v).toLocaleDateString('en-ZA',{day:'numeric',month:'short',year:'numeric'}) : '';
  const timeLabel = (v) => v ? new Date(v).toLocaleString('en-ZA',{day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'}) : '';
  let extended=null, extensionError='', editingAnnouncement=null, editingEvent=null, selectedReport=null, editingLearner=null, insightFrom='', insightTo='', insightGrade='all', insightClass='all', insightMetrics=null, insightBusy=false, insightError='';
  let guardianReviews=null, guardianReviewsError='';
  let staffDirectory=null, staffError='', adminDirectory=null, session=null, store=null, page='dashboard', selectedClass='10B', rollDate=today(), draft={}, selectedLearner='l1', selectedGuardian='p1', selectedChild='l1';
  const icons = {
    home:'<path d="m3 10 9-7 9 7v10H3z"/><path d="M9 20v-7h6v7"/>',
    book:'<path d="M4 5h7a3 3 0 0 1 3 3v12H7a3 3 0 0 0-3 1z"/><path d="M20 5h-3a3 3 0 0 0-3 3v12h3a3 3 0 0 1 3 1z"/>',
    calendar:'<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 3v4M17 3v4M3 10h18"/>',
    megaphone:'<path d="M4 11h4l11-5v12l-11-5H4zM8 13l2 7h3"/>',
    message:'<path d="M20 11.5a8 8 0 0 1-8 8 9 9 0 0 1-4-.9L3 20l1.4-4.7A8 8 0 1 1 20 11.5z"/>',
    bell:'<path d="M18 8a6 6 0 0 0-12 0c0 8-3 8-3 10h18c0-2-3-2-3-10ZM10 21h4"/>',
    check:'<path d="m5 12 5 5L20 7"/>',
    users:'<circle cx="9" cy="8" r="3"/><path d="M2 20v-2a7 7 0 0 1 14 0v2M17 5a3 3 0 0 1 0 6M18 14a6 6 0 0 1 4 6"/>',
    chart:'<path d="M3 20h18M6 16v-5M12 16V5M18 16V9"/>',
    arrow:'<path d="M5 12h14m-6-6 6 6-6 6"/>',
    shield:'<path d="M12 2 20 6v6c0 5-4 8-8 10-4-2-8-5-8-10V6z"/><path d="m8 12 3 3 5-5"/>',
    sparkle:'<path d="m12 2 2.5 7.5L22 12l-7.5 2.5L12 22l-2.5-7.5L2 12l7.5-2.5z"/>'
  };
  const icon=(key,size=19)=>`<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[key]||icons.home}</svg>`;
  const navStaff=[['dashboard','home','Overview'],['rollcall','check','Take attendance'],['learners','users','Learners & marks'],['reports','book','Report cards'],['documents','book','Documents'],['announcements','megaphone','Announcements'],['events','calendar','Calendar'],['messages','message','Messages'],['notifications','bell','Notifications'],['insights','chart','Insights']];

  const staff=()=>session?.role==='Admin'||session?.role==='Teacher';
  const admin=()=>session?.role==='Admin';
  const lrn=()=>store?.learners||[];
  const cls=()=>store?.classes||[];
  const userName=(id)=>(store?.guardians||[]).find(g=>g.id===id)?.name||'Parent';
  const grade=(l)=>String(cls().find(c=>c.id===l?.classId)?.grade||'');
  const avg=(l)=> l?.marks?.length ? Math.round(l.marks.reduce((sum,m)=>sum+m.score,0)/l.marks.length) : 0;
  const notices=()=>store?.announcements||[];
  const roll=()=>store?.rollCalls?.find(r=>r.classId===selectedClass&&r.date===rollDate);
  const currentLearner=()=>lrn().find(l=>l.id===(staff()?selectedLearner:selectedChild))||lrn()[0];
  function toast(s,isError=false){let el=$('toast');el.textContent=s;el.hidden=false;el.style.background=isError?'#8c332d':'#124B74';clearTimeout(toast.timer);toast.timer=setTimeout(()=>el.hidden=true,5200);}
  async function call(url,opts={}){
    const method=opts.method||'GET';
    const resp=await fetch(url,{...opts,credentials:'same-origin',cache:'no-store',headers:{'Accept':'application/json',...(method==='GET'?{}:{...(opts.body instanceof FormData?{}:{'Content-Type':'application/json'}),'X-CSRF-TOKEN':csrf}),...(opts.headers||{})}});
    if(resp.status===401){window.location.href='/login';throw new Error('Session expired');}
    const body=await resp.json().catch(()=>({}));
    if(!resp.ok)throw new Error(body.error||`Request failed (${resp.status}).`);
    return body;
  }
  const post=(url,body)=>call(url,{method:'POST',body:JSON.stringify(body)});
  const mutation=(method,url,body)=>call(url,{method,body:JSON.stringify(body)});
  const destroy=(url)=>call(url,{method:'DELETE'});
  async function loadExtension(){try{extended=await call('/api/extended/bootstrap');extensionError='';}catch(e){extended=null;extensionError=e.message;}}
  async function reload(){const body=await call('/api/bootstrap');session=body.user;store=body.data;
    await loadExtension();
    if(admin()){try{const response=await call('/api/admin/staff');staffDirectory=response.staff;}catch{staffDirectory=null;}}
    if(!lrn().some(l=>l.id===selectedLearner))selectedLearner=lrn()[0]?.id;
    if(!lrn().some(l=>l.id===selectedChild))selectedChild=lrn()[0]?.id;
    if(!cls().some(c=>c.id===selectedClass))selectedClass=cls()[0]?.id;
    if(!(store.guardians||[]).some(g=>g.id===selectedGuardian))selectedGuardian=store.guardians?.[0]?.id;
    render();
  }
  const pill=(x,variant='pill-green')=>`<span class="pill ${variant}">${esc(x)}</span>`;
  const stat=(name,value,note)=>`<article class="card stat"><div class="stat-label">${esc(name)}</div><div class="stat-value">${esc(value)}</div><div class="stat-sub">${esc(note)}</div></article>`;
  const btn=(name,dest,variant='outline')=>`<button type="button" class="button ${variant}" data-go="${esc(dest)}">${esc(name)} ${icon('arrow',15)}</button>`;
  const heading=(title,sub)=>`<div class="section-head"><div><h2>${esc(title)}</h2><p>${esc(sub)}</p></div></div>`;
  function hero(kicker,title,desc,button='',tag='Every day, connected'){
    return `<section class="hero"><div class="hero-copy"><span class="hero-eyebrow">${icon('sparkle',15)} ${esc(kicker)}</span><h2>${esc(title)}</h2><p>${esc(desc)}</p>${button?`<div style="margin-top:20px">${button}</div>`:''}</div><div class="hero-art" aria-hidden="true"><span class="art-circle art-one"></span><span class="art-circle art-two"></span><div class="hero-glass">${icon('shield',31)}<span>${esc(tag)}</span></div></div></section>`;
  }
  function announcementCard(a){return `<article class="feed-item"><div class="feed-icon">${icon('megaphone',19)}</div><div class="feed-copy"><div class="feed-heading">${esc(a.title)}</div><p>${esc(a.body)}</p><span class="feed-meta">${esc(dateLabel(a.createdAt))} · ${a.grade==='all'?'All families':'Grade '+esc(a.grade)}</span></div>${a.status!=='published'?pill(a.status,'pill-gold'):a.priority!=='Normal'?pill(a.priority,'pill-gold'):''}</article>`;}
  function empty(text){return `<div class="empty-note">${esc(text)}</div>`;}
  function userRoll(l){const history=(store.rollCalls||[]).filter(r=>r.statuses?.[l.id]).sort((a,b)=>b.date.localeCompare(a.date));return history;}
  function parentDashboard(){if(!lrn().length) return `${hero('WELCOME TO KAGISHO CONNECT',`Welcome, ${session.name?.split(' ')[0]||'Parent'}.`,'Your parent account is ready to use.')}<section class="card panel connected-empty"><div class="section-icon">${icon('users',28)}</div><h2>We’ll connect your learner next.</h2><p>Your school needs to verify your relationship to your child before academic records, attendance and private updates can appear here.</p><p>Contact the school office to request learner linking. Your account has been created securely.</p>${btn('View school news','announcements')}</section>`;const ch=currentLearner();const alertCount=(store.alerts||[]).filter(a=>!a.isRead).length;
    return `${hero('YOUR FAMILY HUB',`Good morning, ${session.name?.split(' ')[0]||'Parent'}.`,'Everything important about your child, organised in one calm place.',btn('View school news','announcements','white'),'Family & school, together')}
    ${childPicker()}${alertCount?`<div class="top-alert"><div>${icon('bell',21)}<div><strong>${alertCount} attendance alert${alertCount!==1?'s':''} to review</strong><p>Important updates from your child’s school.</p></div></div>${btn('View alerts','alerts')}</div>`:''}
    <div class="stats-grid">${stat('Academic average',`${avg(ch)}%`,'Across current subjects')}${stat('Subjects',String(ch?.marks?.length||0),'Academic overview')}${stat('Unread alerts',String(alertCount),'Your family updates')}</div>
    <div class="two-cols"><section class="card panel">${heading('Learning progress','Your child’s most recent marks')}${marksMini(ch)}${btn('See all subjects','learning')}</section><section class="card panel">${heading('From your school','Recent notices and reminders')}${notices().slice(0,3).map(announcementCard).join('')||empty('No announcements yet.')}${btn('All school news','announcements')}</section></div>`;
  }
  function staffDashboard(){
    const todayRows=(store.rollCalls||[]).filter(r=>r.date===today());
    const counts={Present:0,Absent:0,Late:0};
    for(const r of todayRows)for(const status of Object.values(r.statuses||{}))if(status in counts)counts[status]++;
    const marks=lrn().flatMap(l=>l.marks||[]),overall=marks.length?Math.round(marks.reduce((a,m)=>a+m.score,0)/marks.length):null;
    const events=(store.events||[]).filter(e=>e.schoolDate>=today()).slice(0,4);
    const docs=extended?.totals?.documentCount;
    const staffCount=staffDirectory?.length;
    const parents=extended?.totals?.parentCount??store.guardians?.length??0;
    const totalMarked=Object.values(counts).reduce((a,b)=>a+b,0);
    const gradeGroups=Object.entries(lrn().reduce((out,l)=>{const g=grade(l)||'Other';out[g]=(out[g]||0)+1;return out;},{})).sort((a,b)=>Number(a[0])-Number(b[0]));
    return `${hero('SCHOOL OPERATIONS',`Welcome back, ${session.name||'Teacher'}.`,'All the information you need to run an organised school day, connected to your real records.',btn('Take morning roll call','rollcall','white'),'School and family, connected')}
    ${extensionError?`<div class="empty-note">Additional V5 modules need database setup: ${esc(extensionError)}. Existing features remain available.</div>`:''}
    <div class="stats-grid school-metrics">${stat('Registered learners',extended?.totals?.learnerCount??lrn().length,'Visible to your role')}${stat('Staff',staffCount??'—',admin()?'Active and inactive accounts':'Available to administrators')}${stat('Registered parents',parents,'Visible verified parent profiles')}${stat('Documents',docs??'—','Uploaded school files')}${stat('Present today',counts.Present,'Submitted registers')}${stat('Absent today',counts.Absent,'Submitted registers')}${stat('Late today',counts.Late,'Submitted registers')}${stat('Academic average',overall===null?'—':overall+'%',marks.length+' recorded subject marks')}</div>
    <div class="two-cols"><section class="card panel">${heading('Learners by grade','Based on the learner register')}
      ${gradeGroups.length?gradeGroups.map(([g,n])=>`<div class="chart-item"><div class="row"><strong>Grade ${esc(g)}</strong><span>${n} learner${n===1?'':'s'}</span></div><div class="chart-track"><div class="chart-bar" style="width:${Math.round(n/Math.max(1,lrn().length)*100)}%"></div></div></div>`).join(''):empty('Register learners to see grade distribution.')}
      ${btn('Detailed analytics','insights')}</section>
      <section class="card panel">${heading('Today’s attendance',totalMarked+' registered learner statuses')}
      ${['Present','Absent','Late'].map(k=>`<div class="chart-item"><div class="row"><strong>${k}</strong><span>${counts[k]}</span></div><div class="chart-track"><div class="chart-bar" style="width:${totalMarked?Math.round(counts[k]/totalMarked*100):0}%"></div></div></div>`).join('')}${btn('Take attendance','rollcall')}</section></div>
    <div class="two-cols"><section class="card panel">${heading('School announcements','Latest notices')}${notices().filter(x=>x.status==='published').slice(0,3).map(announcementCard).join('')||empty('No published announcements.')}${btn('Manage announcements','announcements')}</section>
    <section class="card panel">${heading('Upcoming events','Dates that matter')}${events.map(e=>`<article class="feed-item"><div class="feed-icon">${icon('calendar')}</div><div class="feed-copy"><strong>${esc(e.title)}</strong><p>${esc(dateLabel(e.schoolDate))}${e.category?' · '+esc(e.category):''}</p></div></article>`).join('')||empty('No upcoming school events.')}${btn('Open calendar','events')}</section></div>
    <div class="quick-grid">${[['learners','Learners & marks'],['reports','Report cards'],['documents','Documents'],['messages','Parent messaging'],['notifications','Staff notifications']].map(([id,label])=>`<button class="button outline" data-go="${id}">${esc(label)} ${icon('arrow',15)}</button>`).join('')}</div>`;
  }
  function childPicker(){const options=lrn();return `<section class="card child-bar"><div class="child-symbol">${esc(options.find(l=>l.id===selectedChild)?.name?.split(' ').map(x=>x[0]).join('')||'KC')}</div><div><span class="muted-label">YOUR CHILD</span><strong>${esc(currentLearner()?.name||'—')}</strong><span>Grade ${esc(grade(currentLearner()))} · Class ${esc(currentLearner()?.classId||'—')}</span></div><div style="margin-left:auto"><label class="sr-only" for="childPicker">Choose child</label><select id="childPicker" class="control">${options.map(l=>`<option value="${esc(l.id)}" ${l.id===selectedChild?'selected':''}>${esc(l.name)}</option>`).join('')}</select></div></section>`;}
  function marksMini(l){return l?.marks?.length?l.marks.map(m=>`<div class="mini-mark"><span>${esc(m.subject)}</span><div class="meter"><span style="width:${m.score}%"></span></div><strong>${m.score}%</strong></div>`).join(''):empty('No marks recorded.');}
  function parentLearning(){const ch=currentLearner();if(!ch)return `${hero('ACADEMIC GROWTH','Learning, connected.','Your academic reports will appear here once your school links your child to this account.')}${empty('Waiting for school verification of your parent–learner relationship.')}`;return `${hero('ACADEMIC GROWTH','Progress that makes sense.','Clear subject results and reports for your child — without the jargon.')}${childPicker()}<div class="stats-grid">${stat('Average',avg(ch)+'%','Across recorded subjects')}${stat('Highest mark',Math.max(0,...(ch?.marks||[]).map(m=>m.score))+'%','Best recorded subject')}${stat('Subjects',ch?.marks?.length||0,'Currently available')}</div><section class="card panel">${heading('Subject results',`${ch?.name||'Your child'} · ${ch?.classId||''}`)}${marksMini(ch)}<div class="form-actions"><button class="button outline" id="printReport">Print / save PDF ${icon('arrow',15)}</button></div></section>`;}
  function parentAttendance(){const ch=currentLearner();if(!ch)return `${hero('ATTENDANCE','Your family attendance.','Attendance will appear once the school verifies and links your learner.')}${empty('No learner linked to this account yet.')}`;const history=userRoll(ch),p=history.filter(r=>r.statuses[ch.id]==='Present').length;
    return `${hero('ATTENDANCE','Every school day counts.','See when your child was present, absent or late, with a clear history of attendance.')}${childPicker()}<div class="stats-grid">${stat('Days recorded',history.length,'Submitted roll-call records')}${stat('Present',p,'Days on the register')}${stat('Absences',history.filter(r=>r.statuses[ch.id]==='Absent').length,'Recorded absences')}</div>
    <section class="card panel">${heading('Roll-call history','Submitted registers and corrections are reflected here')}${history.length?`<div class="table-scroll"><table class="data-table"><thead><tr><th>Date</th><th>Class</th><th>Status</th><th>Updated</th></tr></thead><tbody>${history.map(r=>`<tr><td>${esc(dateLabel(r.date))}</td><td>${esc(r.classId)}</td><td>${pill(r.statuses[ch.id],r.statuses[ch.id]==='Absent'?'pill-coral':'pill-green')}</td><td>${esc(timeLabel(r.updatedAt))}</td></tr>`).join('')}</tbody></table></div>`:empty('No attendance has been submitted for this child yet.')}</section>`;}
  function alertCard(a){const child=lrn().find(l=>l.id===a.learnerId);const corrected=a.status==='corrected';return `<article class="alert-card ${corrected?'resolved':''} ${!a.isRead?'unread':''}"><div class="alert-symbol">${icon(corrected?'check':'bell',20)}</div><div class="alert-body"><div class="row"><h3>${corrected?'Attendance record updated':'Attendance alert'}</h3>${pill(corrected?'Corrected':'Important',corrected?'pill-green':'pill-coral')}</div><p>${corrected?`The school updated ${esc(child?.name||'your child')}'s register for ${esc(dateLabel(a.date))}. Their current status is <strong>${esc(a.currentStatus)}</strong>.`:`${esc(child?.name||'Your child')} was recorded <strong>absent</strong> at morning roll call on ${esc(dateLabel(a.date))}. If you believe this is incorrect, please contact the school.`}</p><div class="row"><div class="alert-actions">${btn('Message the school','messages')}</div>${!a.isRead?`<button type="button" class="text-button" data-read="${esc(a.id)}">Mark as read</button>`:''}</div><small class="muted">${esc(timeLabel(a.updatedAt))}</small></div></article>`;}
  function alertsPage(){return `${hero('FAMILY NOTIFICATIONS','Important updates, clearly explained.','You’ll see recorded absences and corrected roll calls here, securely linked to your child.')}
    <section class="card panel">${heading('Attendance notifications','Updates created only after submitted roll call')}${store.alerts?.length?store.alerts.map(alertCard).join(''):empty('No attendance alerts yet. When a teacher submits an absence, it will appear here.')}</section>`;}
  function announcementPage(){const edit=notices().find(a=>a.id===editingAnnouncement);
    return `${hero('SCHOOL COMMUNITY','Clear communication for every family.','Create, edit, archive and publish school announcements from one secure place.')}
    <section class="card panel">${heading(edit?'Edit announcement':'Create an announcement',edit?'Update this record or change its publication status.':'Published notices appear in the parent app.')}
    <form id="announcementForm"><div class="form-grid"><label class="field full">Title<input name="title" required maxlength="120" value="${esc(edit?.title||'')}"/></label><label class="field full">Message<textarea name="body" required maxlength="4000">${esc(edit?.body||'')}</textarea></label>
    <label class="field">Audience<select name="grade"><option value="all">All families</option>${Array.from({length:5},(_,i)=>String(i+8)).map(g=>`<option value="${g}" ${edit?.grade===g?'selected':''}>Grade ${g}</option>`).join('')}</select></label>
    <label class="field">Priority<select name="priority">${['Normal','Important','Urgent'].map(k=>`<option ${edit?.priority===k?'selected':''}>${k}</option>`).join('')}</select></label>
    ${edit?`<label class="field">Status<select name="status">${['published','draft','archived'].map(k=>`<option ${edit.status===k?'selected':''}>${k}</option>`).join('')}</select></label>`:''}</div>
    <div class="form-actions"><button class="button primary" type="submit">${edit?'Save changes':'Publish announcement'}</button>${edit?`<button class="button outline" id="cancelAnnouncement" type="button">Cancel</button>`:''}</div></form></section>
    <section class="card panel">${heading('Manage school updates',notices().length+' saved announcements')}
    ${notices().map(a=>`<article class="feed-item manage-feed"><div class="feed-icon">${icon('megaphone',19)}</div><div class="feed-copy"><div class="feed-heading">${esc(a.title)}</div><p>${esc(a.body)}</p><small>${esc(dateLabel(a.createdAt))} · ${esc(a.status||'published')} · ${a.grade==='all'?'All grades':'Grade '+esc(a.grade)}</small></div>
    <div class="action-stack"><button class="button outline" data-edit-ann="${esc(a.id)}">Edit</button><button class="button outline" data-ann-status="${esc(a.id)}" data-next="${a.status==='published'?'archived':'published'}">${a.status==='published'?'Archive':'Publish'}</button>${admin()?`<button class="button danger-outline" data-delete-ann="${esc(a.id)}">Delete</button>`:''}</div></article>`).join('')||empty('No announcements yet.')}</section>`;
  }
  function eventPage(){const edit=(store.events||[]).find(e=>e.id===editingEvent);return `${hero('SCHOOL CALENDAR','Keep every important date in view.','Plan terms, examinations, parent meetings and events. All dates are saved to Supabase.')}
    <section class="card panel">${heading(edit?'Edit a school event':'Add a school event','Events are visible to verified parent accounts in the mobile app.')}
    <form id="eventForm" class="form-grid"><label class="field">Title<input name="title" required maxlength="120" value="${esc(edit?.title||'')}"/></label><label class="field">Date<input type="date" name="date" required value="${esc(edit?.schoolDate||'')}"/></label>
    <label class="field full">Description<textarea name="description" maxlength="2000">${esc(edit?.description||'')}</textarea></label>
    <label class="field">Start time<input name="time" type="time" value="${esc(edit?.startTime||'')}"/></label>
    <label class="field">Category<select name="category">${['General','Exams','Parent meeting','Sports','School activity','Term date'].map(k=>`<option ${edit?.category===k?'selected':''}>${k}</option>`).join('')}</select></label>
    <label class="field">Audience<select name="grade"><option value="all">All families</option>${Array.from({length:5},(_,i)=>String(i+8)).map(g=>`<option value="${g}" ${edit?.grade===g?'selected':''}>Grade ${g}</option>`).join('')}</select></label>
    <div class="form-actions"><button class="button primary">${edit?'Save event changes':'Publish event'}</button>${edit?`<button class="button outline" id="cancelEvent" type="button">Cancel</button>`:''}</div></form></section>
    <section class="card panel">${heading('School events',((store.events||[]).length)+' event(s)')}
    <label class="field">Find events<input id="eventSearch" placeholder="Filter by title, date or category"/></label>
    ${(store.events||[]).map(e=>`<article class="feed-item manage-feed" data-event-search="${esc((e.title+' '+e.schoolDate+' '+e.category).toLowerCase())}"><div class="feed-icon">${icon('calendar')}</div><div class="feed-copy"><strong>${esc(e.title)}</strong><p>${esc(e.description)}</p><small>${esc(dateLabel(e.schoolDate))} · ${esc(e.category)} · ${e.grade==='all'?'All grades':'Grade '+esc(e.grade)}</small></div><div class="action-stack"><button class="button outline" data-edit-event="${esc(e.id)}">Edit</button>${admin()?`<button class="button danger-outline" data-delete-event="${esc(e.id)}">Delete</button>`:''}</div></article>`).join('')||empty('No events in the calendar.')}</section>`;}
  function rollPage(){const room=cls().find(c=>c.id===selectedClass), rosters=lrn().filter(l=>l.classId===selectedClass).sort((a,b)=>a.name.localeCompare(b.name));const statuses=['Present','Absent','Late','Excused'];const existing=roll();let counter={Present:0,Absent:0,Late:0,Excused:0};for(const learner of rosters){if(counter[draft[learner.id]]!==undefined)counter[draft[learner.id]]++;}
    return `${hero('MORNING ROLL CALL','Quick, calm, and accurate.','Take attendance in a few taps. Parent alerts are created only after the register is submitted.','','The school day starts here')}
    <section class="card roll-toolbar"><div class="toolbar-title"><div class="section-icon">${icon('calendar',24)}</div><div><strong>Today’s register</strong><span>One class, one clear process.</span></div></div><div class="toolbar-controls"><label>Class<select id="classPicker" class="control">${cls().map(c=>`<option value="${esc(c.id)}" ${c.id===selectedClass?'selected':''}>${esc(c.name)}</option>`).join('')}</select></label><label>School date<input class="control" id="rollDate" type="date" value="${esc(rollDate)}"/></label></div></section>
    <section class="card panel margin-top"><div class="register-head"><div>${heading(`${esc(room?.name||'Class')} roll call`,`${rosters.length} learners · ${esc(dateLabel(rollDate))}`)}</div><button class="button outline" id="markPresent" type="button">${icon('check',17)} Mark all present</button></div>
    <div class="register-help">${icon('shield',19)} Choose a status for every learner. Review your totals before submitting. No parent is alerted while you are still taking roll.</div>
    <div class="register-list">${rosters.map((l,i)=>`<div class="register-row"><div class="learner-details"><span class="number-chip">${i+1}</span><span class="learner-portrait">${esc(l.name.split(' ').map(x=>x[0]).join(''))}</span><div><strong>${esc(l.name)}</strong><small>${esc(l.classId)} · ${esc(l.id.toUpperCase())}</small></div></div><div class="status-control" role="group" aria-label="Attendance status for ${esc(l.name)}">${statuses.map(s=>`<button type="button" class="status-button ${draft[l.id]===s?'chosen '+s.toLowerCase():''}" data-attend="${esc(l.id)}" data-status="${s}" aria-pressed="${draft[l.id]===s}">${s==='Present'?icon('check',14):''}${s}</button>`).join('')}</div></div>`).join('')}</div>
    <div class="status-summary">${statuses.map(s=>pill(`${s}: ${counter[s]}`,s==='Absent'?'pill-coral':s==='Late'||s==='Excused'?'pill-gold':'pill-green')).join('')}</div>
    <div class="submit-bar"><div><strong>${rosters.length-Object.values(counter).reduce((a,b)=>a+b,0)} learners awaiting a status</strong><p>After submitting, the database saves attendance and creates in-app parent alerts for new absences. Corrections also alert guardians; repeat submissions do not duplicate alerts.</p></div><button class="button primary large" id="submitRoll" type="button">Submit roll call ${icon('arrow',19)}</button></div></section>`;
  }
  function learnersPage(){const student=currentLearner();return `${hero('LEARNER WELLBEING','Progress in your hands.','Manage classroom marks simply and see each learner’s strengths at a glance.')}
    <section class="card panel"><div class="section-head"><div><h2>Learner records</h2><p>Choose a learner and edit a mark, then save.</p></div><label><span class="sr-only">Learner</span><select id="staffLearner" class="control">${lrn().map(l=>`<option value="${esc(l.id)}" ${l.id===student?.id?'selected':''}>${esc(l.name)} · ${esc(l.classId)}</option>`).join('')}</select></label></div>
    <div class="child-bar" style="padding-left:0"><div class="child-symbol">${esc(student?.name?.split(' ').map(x=>x[0]).join('')||'KC')}</div><div><span class="muted-label">ACADEMIC OVERVIEW</span><strong>${esc(student?.name||'—')}</strong><span>${esc(student?.classId||'')} · Parent: ${esc(userName(student?.guardianId))}</span></div><div class="child-hint">Average: ${avg(student)}%</div></div>
    <div class="table-scroll"><table class="data-table"><thead><tr><th>Subject</th><th>Result</th><th>Progress</th><th>New mark</th><th>Action</th></tr></thead><tbody>${(student?.marks||[]).map(m=>`<tr><td class="strong">${esc(m.subject)}</td><td>${m.score}%</td><td><div class="meter"><span style="width:${m.score}%"></span></div></td><td><label class="sr-only" for="score-${esc(m.subject.replace(/\W/g,''))}">Score for ${esc(m.subject)}</label><input type="number" min="0" max="100" value="${m.score}" id="score-${esc(m.subject.replace(/\W/g,''))}" data-score="${esc(m.subject)}" class="number-field"></td><td><button class="button outline" type="button" data-save-mark="${esc(m.subject)}">Save</button></td></tr>`).join('')}</tbody></table></div><form id="newMarkForm" class="form-grid" style="margin-top:24px"><label class="field">Subject<input name="subject" required maxlength="80" placeholder="Mathematics"></label><label class="field">Score (%)<input type="number" name="score" min="0" max="100" required></label><button type="submit" class="button primary" ${student?'':'disabled'}>Add or update subject</button></form></section>`;}
  function messagePage(){const messages=(store.messages||[]).filter(m=>m.guardianId===selectedGuardian);const gName=userName(selectedGuardian);return `${hero('REAL CONVERSATIONS','Communication that goes both ways.','A clear space for respectful messages between school staff and parents.')}
    <div class="message-layout"><section class="card panel"><h2>Conversations</h2><p class="section-desc">${staff()?'Choose a parent or guardian':'Your family and the school'}</p>${(store.guardians||[]).map(g=>`<button type="button" class="thread-option ${g.id===selectedGuardian?'selected':''}" data-thread="${esc(g.id)}"><span class="person-avatar">${esc(g.name.split(' ').map(x=>x[0]).join(''))}</span><span><strong>${esc(g.name)}</strong><small>${store.messages.filter(m=>m.guardianId===g.id).length} messages</small></span></button>`).join('')}</section><section class="card panel"><div class="conversation-title"><span class="person-avatar">${esc(gName.split(' ').map(x=>x[0]).join(''))}</span><div><strong>${staff()?esc(gName):'Kagisho High School'}</strong><small>School and family conversation</small></div></div><div id="thread" class="message-history">${messages.length?messages.map(m=>`<div class="chat-bubble ${((m.sender==='staff')===staff())?'mine':''}"><small>${m.sender==='staff'?'School staff':esc(gName)} · ${esc(timeLabel(m.createdAt))}</small><p>${esc(m.text)}</p></div>`).join(''):empty('No messages yet. Start a friendly conversation.')}</div>${staff()||lrn().length?`<form id="messageForm" class="composer"><input name="text" required maxlength="1000" placeholder="Write a message…" aria-label="Write a message"/><button class="button primary" type="submit">Send ${icon('arrow',16)}</button></form>`:empty('Your account will be linked to a learner by the school before messaging is available.')}</section></div>`;}
  async function refreshInsights(){
    if(!extended)return;
    insightBusy=true;insightError='';
    try{insightMetrics=await post('/api/extended/attendance/summary',{
      start:insightFrom||String(new Date().getFullYear())+'-01-01',end:insightTo||today(),grade:insightGrade,classId:insightClass});
    }catch(e){insightMetrics=null;insightError=e.message;}
    finally{insightBusy=false;if(page==='insights')render();}
  }
  function insightsPage(){const data=insightMetrics,total=Number(data?.total||0),present=Number(data?.present||0),absent=Number(data?.absent||0),late=Number(data?.late||0);
    const gradeGroups=[...new Set(lrn().map(grade))].sort((a,b)=>Number(a)-Number(b));
    const subjectMarks=lrn().flatMap(l=>(l.marks||[]).map(m=>({...m,grade:grade(l)}))).filter(m=>insightGrade==='all'||m.grade===insightGrade);
    const subjects=[...new Set(subjectMarks.map(m=>m.subject))];
    return `${hero('SCHOOL ANALYTICS','Make informed decisions with real data.','Attendance totals are aggregated by the database across the full chosen period, never estimated from a 1,000-row sample.')}
    <section class="card panel">${heading('Report filters','Default: academic year to date. Use any date range up to 730 days.')}
    <div class="form-grid"><label class="field">From<input type="date" id="insightFrom" value="${esc(insightFrom||String(new Date().getFullYear())+'-01-01')}"/></label>
    <label class="field">To<input type="date" id="insightTo" value="${esc(insightTo||today())}"/></label>
    <label class="field">Grade<select id="insightGrade"><option value="all">All grades</option>${gradeGroups.map(g=>`<option value="${esc(g)}" ${insightGrade===g?'selected':''}>Grade ${esc(g)}</option>`).join('')}</select></label>
    <label class="field">Class<select id="insightClass"><option value="all">All classes</option>${cls().filter(c=>insightGrade==='all'||String(c.grade)===insightGrade).map(c=>`<option value="${esc(c.id)}" ${insightClass===c.id?'selected':''}>${esc(c.name)}</option>`).join('')}</select></label></div>
    <div class="quick-grid"><button class="button outline" data-report-preset="today">Today</button><button class="button outline" data-report-preset="week">7 days</button><button class="button outline" data-report-preset="month">30 days</button><button class="button outline" data-report-preset="year">Year to date</button></div>
    <div class="form-actions"><button class="button outline" id="exportAttendanceCsv" ${data?'':'disabled'}>Download class summary CSV (Excel)</button><button class="button outline" id="printInsights">Print / Save PDF</button><button class="button outline" id="clearInsights">Clear filters</button></div>
    ${insightBusy?empty('Loading fresh database analytics…'):insightError?`<div class="empty-note">${esc(insightError)}</div>`:!data?empty('Select filters to load database attendance statistics.'):''}</section>
    <div class="stats-grid">${stat('Attendance entries',data?total:'—','All dates in the selected period')}${stat('Present',data?present:'—','Submitted statuses')}${stat('Absent',data?absent:'—','Submitted statuses')}${stat('Late',data?late:'—','Submitted statuses')}${stat('Attendance rate',data&&total?Math.round(100*present/total)+'%':'—','Present ÷ all statuses')}</div>
    <div class="two-cols"><section class="card panel">${heading('Attendance by class','Full database totals within selected dates')}
    ${(data?.classes||[]).map(c=>{const rate=Number(c.total)>0?Math.round(Number(c.present)/Number(c.total)*100):0;return `<div class="chart-item"><div class="row"><span>${esc(c.className)}</span><strong>${rate}% · ${esc(c.total)} entries</strong></div><div class="chart-track"><div class="chart-bar" style="width:${rate}%"></div></div></div>`;}).join('')||empty('No submitted attendance for this selection.')}</section>
    <section class="card panel">${heading('Subject performance','Current quick marks for visible learners')}
    ${subjects.map(sub=>{const x=subjectMarks.filter(m=>m.subject===sub),rate=Math.round(x.reduce((a,m)=>a+m.score,0)/x.length);return `<div class="chart-item"><div class="row"><span>${esc(sub)}</span><strong>${rate}% · ${x.length} result(s)</strong></div><div class="chart-track"><div class="chart-bar" style="width:${rate}%"></div></div></div>`;}).join('')||empty('No subject results recorded.')}</section></div>
    <section class="card panel">${heading('Learners requiring attendance follow-up','Two or more absences during the chosen period')}
      ${(data?.frequentAbsences||[]).map(r=>`<div class="feed-item"><div class="feed-copy"><strong>${esc(r.learnerName)}</strong><small> Learner UUID: ${esc(r.learnerId)}</small></div><span>${esc(r.absences)} absences</span></div>`).join('')||empty('No learner has two or more recorded absences in this period.')}</section>`;
  }

  async function refreshStaff(){
    staffError='';
    try{const response=await call('/api/admin/staff');staffDirectory=response.staff;}
    catch(err){staffError=err.message;staffDirectory=[];}
    if(page==='staff')render();
  }
  function staffPage(){if(!admin())return empty('You do not have access to this section.');
    return `${hero('PEOPLE & PERMISSIONS','A school team, thoughtfully managed.','Invite trusted staff, manage their access and keep your school workspace organised.')}
      <div class="stats-grid">${stat('Staff members',staffDirectory?.length??'—','Registered in Supabase')}${stat('Active staff',staffDirectory?.filter(s=>s.active).length??'—','Allowed to sign in')}${stat('Invitations','Email','Secure account activation')}</div>
      <div class="two-cols"><section class="card panel">${heading('Invite a staff member','Only school administrators can create staff accounts.')}
      <form id="inviteStaffForm" class="login-form"><label class="field"><span>Full name</span><input name="name" required minlength="2" maxlength="100" placeholder="e.g. Lerato Dlamini"/></label>
      <label class="field"><span>Work email</span><input type="email" name="email" required maxlength="254" placeholder="name@school.co.za"/></label>
      <label class="field"><span>Role</span><select name="role"><option value="Teacher">Teacher</option><option value="Admin">School administrator</option></select></label>
      <button class="button primary" type="submit">Send staff invitation ${icon('arrow',16)}</button></form>
      <p class="section-desc">The staff member receives an email to set their own password. Staff cannot self-register.</p></section>
      <section class="card panel">${heading('Staff directory','Real staff accounts managed through your connected Supabase project')}
      ${staffError?`<div class="empty-note">${esc(staffError)}</div>`:staffDirectory===null?empty('Loading staff directory…'):
      !staffDirectory.length?empty('No staff members have been added yet. Create the first administrator using the setup guide.'):
      `<div class="staff-list">${staffDirectory.map(person=>`<div class="staff-row"><span class="person-avatar">${esc(person.fullName.split(' ').map(p=>p[0]).join('').slice(0,2))}</span>
      <div class="staff-details"><strong>${esc(person.fullName)}</strong><small>${esc(person.email)}</small><span>${pill(person.role,'pill-green')} ${pill(person.active?'Active':'Inactive',person.active?'pill-green':'pill-gold')}</span></div>
      ${person.userId===session.id?'<span class="muted small">Your account</span>':`<button class="button outline" type="button" data-set-active="${esc(person.userId)}" data-active="${!person.active}">${person.active?'Deactivate':'Activate'}</button>`}</div>`).join('')}</div>`}</section></div>`;
  }


  async function refreshAdmin(){
    try{const [directory,staffList]=await Promise.all([call('/api/admin/directory'),call('/api/admin/staff')]);adminDirectory=directory;staffDirectory=staffList.staff;}
    catch(err){toast('Could not load school administrator data: '+err.message,true);adminDirectory={parents:[],links:[],assignments:[]};}
    await refreshGuardianRequests();
    if(page==='manage')render();
  }
  async function refreshGuardianRequests(){
    try{guardianReviews=await call('/api/extended/guardian-requests');guardianReviewsError='';}
    catch(err){guardianReviews={requests:[],birthdates:[]};guardianReviewsError=err.message;}
  }
  function guardianReviewsPanel(){
    const requests=guardianReviews?.requests||[];
    const dates=guardianReviews?.birthdates||[];
    const people=adminDirectory?.parents||[];
    const normalizeName=(x)=>String(x||'').trim().replace(/\s+/g,' ').toLocaleLowerCase();
    const matchingLearners=(r)=>lrn().filter(l=>normalizeName(l.name)===normalizeName(r.child_name)
      &&dates.some(d=>d.learner_id===l.id&&d.birth_date===r.child_birth_date));
    return `<section class="card panel">${heading('Parent access requests','Parents enter their child’s name and date of birth. Administrators verify guardianship, then approve or reject.')}
      ${guardianReviewsError?`<div class="empty-note">Apply migration 04_parent_experience.sql to enable requests. ${esc(guardianReviewsError)}</div>`:''}
      <form id="learnerBirthdateForm" class="form-grid">
        <label class="field">Learner with a verified school record<select name="learnerId" required>${lrn().map(l=>`<option value="${esc(l.id)}">${esc(l.name)} · ${esc(grade(l))}</option>`).join('')}</select></label>
        <label class="field">Date of birth (private; admins only)<input type="date" name="date" required/></label>
        <button class="button primary" ${lrn().length?'':'disabled'}>Save learner date of birth</button>
      </form>
      <p class="muted">${dates.length} learner DOB record(s) securely stored. Date of birth is never shown in the parent app. Confirm a parent’s identity and guardianship independently before approval.</p>
      <div class="table-scroll"><table class="data-table"><thead><tr><th>Parent</th><th>Claimed learner</th><th>Date of birth</th><th>Status</th><th>Review</th></tr></thead><tbody>
        ${requests.map(r=>`<tr><td>${esc(people.find(p=>p.user_id===r.parent_id)?.full_name||'Registered parent')}<br><small>${esc(people.find(p=>p.user_id===r.parent_id)?.email||'')}</small></td>
          <td>${esc(r.child_name)}${r.status==='pending'?`<br><small class="muted">${matchingLearners(r).length===1?'School record matches; independently verify guardianship':matchingLearners(r).length===0?'No matching learner + verified DOB; check records first':'Multiple matching records; resolve duplicates'}</small>`:''}</td><td>${esc(r.child_birth_date)}</td><td>${pill(r.status,r.status==='approved'?'pill-green':'pill-gold')}</td>
          <td>${r.status==='pending'?`<div class="action-stack"><button class="button primary" data-guardian-review="${esc(r.id)}" data-approve="true">Approve</button><button class="button danger-outline" data-guardian-review="${esc(r.id)}" data-approve="false">Reject</button></div>`:'Reviewed'}</td></tr>`).join('')||'<tr><td colspan="5">No requests submitted yet.</td></tr>'}
      </tbody></table></div></section>`;
  }
  function managePage(){
    if(!admin())return empty('This section is for school administrators.');
    const options=(arr,value,label)=>arr.map(v=>`<option value="${esc(v[value])}">${esc(v[label])}</option>`).join('');
    const parents=adminDirectory?.parents||[];
    const teachers=(staffDirectory||[]).filter(s=>s.role==='Teacher'&&s.active);
    const classes=cls(),learners=lrn();
    const links=adminDirectory?.links||[];
    const target=learners.find(l=>l.id===editingLearner);
    return `${hero('SCHOOL DIRECTORY','Your school, organised.','Create school classes and learners, assign teachers and verify parent–child relationships.','','Verified and connected')}
      <section class="card panel">${heading('Classes and learners','Add a class first. Each learner is registered with a verified date of birth.')}
      <div class="two-cols"><form id="classForm" class="login-form"><h3>Create a class</h3><label class="field">Class name<input name="name" placeholder="Grade 10B" required minlength="2" maxlength="40" /></label><label class="field">Grade<select name="grade">${Array.from({length:5},(_,i)=>`<option value="${i+8}" ${i===2?'selected':''}>Grade ${i+8}</option>`).join('')}</select></label><button class="button primary">Save class</button></form>
      <form id="learnerForm" class="login-form"><h3>Add a learner</h3><label class="field">Learner full name<input name="name" required maxlength="100" placeholder="Fictional learner name"/></label><label class="field">Class<select name="classId" required>${options(classes,'id','name')}</select></label><label class="field">Unique admission number<input name="admissionNumber" required minlength="4" maxlength="32" placeholder="e.g. KG-2026-0001"/></label><label class="field">Verified date of birth (school record)<input name="birthDate" type="date" min="1990-01-01" max="${today()}" required /></label><p class="muted">Enter the date of birth from the school's verified record; this enables later guardian-request matching. Do not use a parent's unverified claim.</p><button class="button primary" ${classes.length?'':'disabled'}>Save learner</button></form></div></section>
      ${guardianReviewsPanel()}
      <section class="card panel">${heading('Secure access and assignments','Only school staff can approve parent links. Teachers need assigned classes.')}
      <div class="two-cols"><div class="empty-note"><h3>Parent-requested access</h3>Parents submit the learner’s name and date of birth in their app. Review the request above instead of manually linking accounts. Matching details do not replace proof of guardianship.</div>
      <form id="assignClassForm" class="login-form"><h3>Assign teacher to class</h3><label class="field">Teacher<select name="userId" required>${options(teachers,'userId','fullName')}</select></label><label class="field">Class<select name="classId" required>${options(classes,'id','name')}</select></label><button class="button primary" ${teachers.length&&classes.length?'':'disabled'}>Assign class</button></form></div></section>
      ${target?`<section class="card panel">${heading('Edit learner','Updates keep the same learner UUID across all modules')}<form id="editLearnerForm" class="form-grid"><label class="field">Full name<input name="name" required maxlength="100" value="${esc(target.name)}"/></label><label class="field">Class<select name="classId">${classes.map(c=>`<option value="${esc(c.id)}" ${target.classId===c.id?'selected':''}>${esc(c.name)}</option>`).join('')}</select></label><label class="field">Admission number<input name="admissionNumber" minlength="4" maxlength="32" value="${esc(target.admissionNumber||'')}"/></label><label class="field"><input type="checkbox" name="active" checked/> Active learner</label><div class="form-actions"><button class="button primary">Save learner</button><button type="button" class="button outline" id="cancelLearner">Cancel</button></div></form><small class="muted">Deactivating a learner removes them from active registers; historical records remain in the database.</small></section>`:''}
      <section class="card panel">${heading('Current learners',`${learners.length} active learner(s) in the system`)}
      <label class="field">Search learner by name, grade or learner UUID<input id="learnerSearch" placeholder="Search the learner directory"/></label>
      ${learners.length?`<div class="table-scroll"><table class="data-table"><thead><tr><th>Learner</th><th>Class</th><th>Verified guardians</th><th>Manage</th></tr></thead><tbody>${learners.map(l=>`<tr data-learner-search="${esc((l.name+' '+l.admissionNumber+' '+(classes.find(c=>c.id===l.classId)?.name||'')+' '+l.id).toLowerCase())}"><td><strong>${esc(l.name)}</strong><br><small class="muted">${esc(l.admissionNumber||'No admission number')} · ${esc(l.id)}</small></td><td>${esc(classes.find(c=>c.id===l.classId)?.name||'—')}</td><td>${links.filter(x=>x.learner_id===l.id).map(x=>`<span class="guardian-chip">${esc(parents.find(p=>p.user_id===x.user_id)?.full_name||userName(x.user_id))} <button title="Remove verified guardian link" data-unlink-learner="${esc(l.id)}" data-unlink-parent="${esc(x.user_id)}">×</button></span>`).join('')||'Pending'}</td><td><button class="button outline" data-edit-learner="${esc(l.id)}">Edit</button></td></tr>`).join('')}</tbody></table></div>`:empty('Add the first class and learner to begin.')}</section>`;
  }

  function extensionNotice(){return `<div class="empty-note">This module needs the new Supabase migration <strong>database/03_portal_extension.sql</strong>. ${esc(extensionError||'Database is not connected.')}</div>`;}
  const docList=()=>extended?.documents||[];
  function documentsPage(){if(!extended)return extensionNotice();return `${hero('DOCUMENT LIBRARY','Every school document, in one secure place.','Upload, organise and share school documents with an actual private storage bucket.')}
    <div class="stats-grid">${stat('Total documents',extended.totals?.documentCount??docList().length,'Exact database count')}${stat('Published',docList().filter(d=>d.published).length,'Approved documents')}${stat('Categories',new Set(docList().map(d=>d.category)).size,'Organised library')}</div>
    <section class="card panel">${heading('Upload document','Private files · PDF, Word, Excel, PNG and JPG · maximum 15MB')}
    <form id="documentForm" enctype="multipart/form-data"><div class="form-grid"><label class="field">Title<input name="title" required maxlength="160"/></label><label class="field">Category<select name="category">${['General','Policies','Forms','Assignments','Academics','Parent letters','Examinations'].map(k=>`<option>${k}</option>`).join('')}</select></label><label class="field">Audience<select name="grade"><option value="all">All grades</option>${Array.from({length:5},(_,i)=>`<option value="${i+8}">Grade ${i+8}</option>`).join('')}</select></label><label class="field">File<input name="file" type="file" accept=".pdf,.doc,.docx,.xls,.xlsx,.png,.jpeg,.jpg" required/></label><label class="field full">Description<textarea name="description" maxlength="2000"></textarea></label><label class="field checkbox-line"><input type="checkbox" name="published"/> Mark as published</label></div><button class="button primary" type="submit">Upload securely</button></form></section>
    <section class="card panel">${heading('Manage documents',`Showing ${docList().length} recent documents · total ${extended.totals?.documentCount??docList().length}`)}<label class="field">Search documents<input id="docSearch" placeholder="Search title, category or grade"/></label>
    ${docList().length?`<div class="table-scroll"><table class="data-table"><thead><tr><th>Document</th><th>Category</th><th>Audience</th><th>Published</th><th>Actions</th></tr></thead><tbody>${docList().map(d=>`<tr data-doc-search="${esc((d.title+' '+d.category+' '+(d.grade||'all')).toLowerCase())}"><td><strong>${esc(d.title)}</strong><br><small class="muted">${esc(d.original_name)} · ${esc(dateLabel(d.created_at))}</small></td><td>${esc(d.category)}</td><td>${d.grade?'Grade '+d.grade:'All'}</td><td>${pill(d.published?'Published':'Draft',d.published?'pill-green':'pill-gold')}</td><td><div class="action-stack">${["application/pdf","image/jpeg","image/png"].includes(d.mime_type)?`<a class="button outline" target="_blank" rel="noopener" href="/api/extended/documents/${esc(d.id)}/preview">Preview</a>`:""}<a class="button outline" href="/api/extended/documents/${esc(d.id)}/download">Download</a><button class="button outline" data-doc-status="${esc(d.id)}" data-publish="${!d.published}">${d.published?'Unpublish':'Publish'}</button><button class="button danger-outline" data-delete-doc="${esc(d.id)}">Delete</button></div></td></tr>`).join('')}</tbody></table></div>`:empty('No documents uploaded yet.')}</section>`;}
  const reportList=()=>extended?.reports||[];
  function reportsPage(){if(!extended)return extensionNotice();const chosen=reportList().find(r=>r.id===selectedReport);const subjects=(extended.reportMarks||[]).filter(m=>m.report_id===selectedReport);const student=lrn().find(l=>l.id===chosen?.learner_id);const term=extended.terms?.find(t=>t.id===chosen?.term_id);const mean=subjects.length?Math.round(subjects.reduce((n,m)=>n+Number(m.percentage),0)/subjects.length*10)/10:0;
    return `${hero('ACADEMIC REPORTS','Academic progress that is clear and complete.','Create term report cards, add subject marks, review drafts and publish approved reports.')}
    ${admin()?`<section class="card panel">${heading('Academic terms','Set the start and end dates for each term')}<form id="termForm" class="form-grid"><label class="field">Academic year<input type="number" name="year" min="2020" max="2100" value="${new Date().getFullYear()}" required/></label><label class="field">Term<select name="term">${[1,2,3,4].map(n=>`<option>${n}</option>`).join('')}</select></label><label class="field">Starts<input type="date" name="start" required/></label><label class="field">Ends<input type="date" name="end" required/></label><button class="button primary">Save term</button></form></section>`:''}
    <section class="card panel">${heading('Create a report card','Each learner has one report card per school term')}<form id="createReportForm" class="form-grid"><label class="field">Learner<select name="learnerId">${lrn().map(l=>`<option value="${esc(l.id)}">${esc(l.name)} · Grade ${esc(grade(l))}</option>`).join('')}</select></label><label class="field">Academic term<select name="termId">${(extended.terms||[]).map(t=>`<option value="${esc(t.id)}">${t.academic_year} · Term ${t.term_no}</option>`).join('')}</select></label><label class="field full">Teacher comment<textarea name="comment" maxlength="1500"></textarea></label><button class="button primary" ${(extended.terms||[]).length?'':'disabled'}>Create draft report</button></form></section>
    <section class="card panel">${heading('Report cards',reportList().length+' reports in your school records')}<label class="field">Select report<select id="reportSelector"><option value="">Choose a report</option>${reportList().map(r=>{const l=lrn().find(l=>l.id===r.learner_id);const t=extended.terms?.find(t=>t.id===r.term_id);return `<option value="${esc(r.id)}" ${selectedReport===r.id?'selected':''}>${esc(l?.name||'Learner')} · ${t?.academic_year||'Year'} T${t?.term_no||'?'} · ${esc(r.status)}</option>`;}).join('')}</select></label>
    ${chosen?`<div class="report-sheet" id="reportPrint"><div class="report-heading"><strong>KAGISHO HIGH SCHOOL</strong><span>${esc(chosen.status.toUpperCase())}</span></div><h2>${esc(student?.name||'Learner')} — Academic report</h2><p>${term?.academic_year||''} · Term ${term?.term_no||''} · Grade ${esc(grade(student))}</p>
    <div class="table-scroll"><table class="data-table"><thead><tr><th>Subject</th><th>Percentage</th><th>Achievement</th></tr></thead><tbody>${subjects.map(m=>`<tr><td>${esc(m.subject)}</td><td>${esc(m.percentage)}%</td><td>${Number(m.percentage)>=80?'Outstanding':Number(m.percentage)>=70?'Meritorious':Number(m.percentage)>=50?'Achieved':'Needs support'}</td></tr>`).join('')}</tbody></table></div><p><strong>Average:</strong> ${subjects.length?mean+'%':'Not available'} (${subjects.length} subjects)</p><p><strong>Teacher comment:</strong> ${esc(chosen.teacher_comment||'No comments added.')}</p></div>
    ${chosen.status==='draft'?`<form id="reportMarkForm" class="form-grid"><label class="field">Subject<input name="subject" required minlength="2" maxlength="80"/></label><label class="field">Percentage<input name="percentage" type="number" min="0" max="100" step="0.01" required/></label><button class="button primary">Save subject mark</button></form>`:''}
    <form id="reportStatusForm"><label class="field">Teacher comment<textarea name="comment" maxlength="1500" ${chosen.status==='published'&&!admin()?'disabled':''}>${esc(chosen.teacher_comment)}</textarea></label><div class="form-actions">${chosen.status==='draft'?`<button type="submit" data-report-publish="true" class="button primary">Publish report</button>`:admin()?`<button type="submit" data-report-publish="false" class="button outline">Unpublish for correction</button>`:''}<button id="printReportCard" class="button outline" type="button">Print / Save as PDF</button></div></form>`:''}</section>`;}
  function notificationsPage(){const lastRead=new Map((extended?.messageReads||[]).map(x=>[x.guardian_id,x.last_read_at]));const unread=(store.messages||[]).filter(m=>m.sender==='parent'&&m.createdAt>(lastRead.get(m.guardianId)||''));const groups=[...new Set(unread.map(m=>m.guardianId))];const important=notices().filter(n=>n.priority!=='Normal'&&n.status==='published');const events=(store.events||[]).filter(e=>e.schoolDate>=today()).slice(0,6);return `${hero('STAFF INBOX','Never miss an important update.','New parent replies, school notices and upcoming events brought together.')}
    ${extended?'':extensionNotice()}<div class="stats-grid">${stat('New parent messages',unread.length,'Not yet marked as read')}${stat('Important notices',important.length,'Published announcements')}${stat('Upcoming events',events.length,'School calendar')}</div>
    <section class="card panel">${heading('Parent messages','Read status is saved per staff account')}${groups.map(g=>`<article class="feed-item manage-feed"><div class="feed-icon">${icon('message')}</div><div class="feed-copy"><strong>${esc(userName(g))}</strong><p>${unread.filter(m=>m.guardianId===g).length} new message(s)</p></div><button class="button primary" data-view-message="${esc(g)}">Open conversation</button></article>`).join('')||empty('No unread parent messages.')}</section>
    <div class="two-cols"><section class="card panel">${heading('Important announcements','Published priority updates')}${important.slice(0,5).map(announcementCard).join('')||empty('No priority announcements.')}</section><section class="card panel">${heading('Upcoming events','Next dates')}${events.map(e=>`<article class="feed-item"><strong>${esc(e.title)} · ${esc(dateLabel(e.schoolDate))}</strong></article>`).join('')||empty('No upcoming events.')}</section></div>`;}
  function auditPage(){if(!admin())return empty('Administrators only.');if(!extended)return extensionNotice();const events=extended.audit||[];
    return `${hero('ACCOUNTABILITY','A clear audit trail for important changes.','See who changed learner records, notices, report cards and school documents.')}
    <div class="stats-grid">${stat('Recent recorded actions',events.length,'Latest 200 audited operations')}${stat('Changes',events.filter(e=>e.operation==='UPDATE').length,'Record updates')}${stat('Deletions',events.filter(e=>e.operation==='DELETE').length,'Record removals')}</div>
    <section class="card panel">${heading('Activity history','Saved by PostgreSQL triggers, not simulated by the website')}
    <label class="field">Search by module or action<input id="auditSearch" placeholder="Search audit records"/></label>
    ${events.length?`<div class="table-scroll"><table class="data-table"><thead><tr><th>When</th><th>Action</th><th>Module</th><th>Staff UUID</th><th>Record UUID</th></tr></thead><tbody>${events.map(e=>`<tr data-audit-search="${esc((e.operation+' '+e.table_name+' '+e.actor+' '+e.record_id).toLowerCase())}"><td>${esc(timeLabel(e.occurred_at))}</td><td>${esc(e.operation)}</td><td>${esc(e.table_name)}</td><td><small>${esc(e.actor)}</small></td><td><small>${esc(e.record_id)}</small></td></tr>`).join('')}</tbody></table></div>`:empty('No audit events recorded since the migration.')}</section>`;
  }
  function pageBody(){switch(page){case 'staff':return staffPage();case 'manage':return managePage();case 'events':return eventPage();case 'reports':return reportsPage();case 'documents':return documentsPage();case 'notifications':return notificationsPage();case 'audit':return auditPage();case 'rollcall':return rollPage();case 'learners':return learnersPage();case 'learning':return parentLearning();case 'attendance':return parentAttendance();case 'alerts':return alertsPage();case 'announcements':return announcementPage();case 'messages':return messagePage();case 'insights':return insightsPage();default:return staff()?staffDashboard():parentDashboard();}}
  function render(){const nav=admin()?[...navStaff,['manage','users','Manage learners'],['staff','users','Manage staff'],['audit','shield','Audit trail']]:navStaff;const titles={dashboard:staff()?'School overview':'Your home',rollcall:'Take attendance',learners:'Learners & marks',learning:'Learning progress',attendance:'Attendance',alerts:'Family alerts',announcements:'School news',events:'School calendar',messages:'Messages',insights:'School insights',reports:'Report cards',documents:'Documents',notifications:'Staff notifications',audit:'Audit trail',staff:'Staff directory',manage:'Manage learners'};
    const count=store.alerts?.filter(a=>!a.isRead).length||0;
    $('app').innerHTML=`<div class="layout"><aside class="sidebar"><div class="brand"><span class="brand-icon">${icon('sparkle',22)}</span><div><strong>Kagisho<span>Connect</span></strong><small>Better together, every day.</small></div></div><div class="menu-label">${staff()?'SCHOOL WORKSPACE':'PARENT SPACE'}</div><nav class="side-nav" aria-label="Primary navigation">${nav.map(([id,ico,name])=>`<button type="button" data-go="${id}" class="nav-link ${page===id?'active':''}" ${page===id?'aria-current="page"':''}>${icon(ico,19)} <span>${esc(name)}</span>${id==='alerts'&&count?`<span class="notification-count">${count}</span>`:''}</button>`).join('')}</nav><div class="sidebar-bottom"><div class="comfort-icon">${icon('shield',22)}</div><strong>Made for real school days.</strong><p>Simple tools for families and the people who teach their children.</p></div><div class="sidebar-meta">Kagisho High School · ELEV8</div></aside>
    <div class="main-shell"><header class="topbar"><div class="crumb">Kagisho Connect <span>›</span> ${esc(titles[page]||'Overview')}</div><div class="top-right">${staff()?'':''}${!staff()?`<button class="icon-button" data-go="alerts" title="View alerts">${icon('bell',20)}${count?'<span class="notif-dot"></span>':''}</button>`:''}<span class="mini-avatar">${esc((session.name||'KC').split(' ').map(s=>s[0]).join(''))}</span><form action="/logout" method="post"><input type="hidden" name="__RequestVerificationToken" value="${esc(csrf)}"><button class="quiet-btn" type="submit">Sign out</button></form></div></header>
    <main class="main"><div class="page-head"><div><div class="eyebrow">${staff()?'SCHOOL PORTAL':'FAMILY PORTAL'}</div><h1>${esc(titles[page]||'Overview')}</h1><p>Welcome, ${esc(session.name)}.</p></div></div>${pageBody()}<footer class="footer"><span>© 2026 Kagisho Connect · ELEV8 · School & family communication</span><span>School & family, connected</span></footer></main></div></div>`;
    handlers();
  }
  function restoreDraft(){const current=roll();draft={};for(const l of lrn().filter(x=>x.classId===selectedClass)){if(current?.statuses?.[l.id])draft[l.id]=current.statuses[l.id];}}
  function goto(id){if((id==='staff'||id==='manage'||id==='audit')&&!admin())return;page=id;render();if(id==='staff')refreshStaff();if(id==='manage')refreshAdmin();if(id==='insights')refreshInsights();window.scrollTo(0,0);}
  function handlers(){
    document.querySelectorAll('[data-go]').forEach(x=>x.addEventListener('click',()=>goto(x.dataset.go)));
    $('childPicker')?.addEventListener('change',e=>{selectedChild=e.target.value;render();});
    $('staffLearner')?.addEventListener('change',e=>{selectedLearner=e.target.value;render();});
    $('classPicker')?.addEventListener('change',e=>{selectedClass=e.target.value;restoreDraft();render();});
    $('rollDate')?.addEventListener('change',e=>{rollDate=e.target.value;restoreDraft();render();});
    $('markPresent')?.addEventListener('click',()=>{for(const l of lrn().filter(l=>l.classId===selectedClass))draft[l.id]='Present';render();toast('Everyone marked present. You can now record any absence before submitting.');});
    document.querySelectorAll('[data-attend]').forEach(b=>b.addEventListener('click',()=>{draft[b.dataset.attend]=b.dataset.status;render();}));
    $('submitRoll')?.addEventListener('click',async()=>{
      const roster=lrn().filter(x=>x.classId===selectedClass);
      if(roster.some(l=>!draft[l.id])){toast('Please select an attendance status for every learner.',true);return;}
      if(!confirm(`Save attendance for ${roster.length} learners in ${selectedClass} on ${dateLabel(rollDate)}?`))return;
      try{const res=await post('/api/attendance',{classId:selectedClass,date:rollDate,statuses:draft});await reload();toast(`Register saved. ${res.created} absence alert(s), ${res.corrected} correction(s) created.`);}catch(e){toast(e.message,true);}
    });
    document.querySelectorAll('[data-save-mark]').forEach(b=>b.addEventListener('click',async()=>{
      const student=currentLearner();const inp=[...document.querySelectorAll('input[data-score]')].find(x=>x.dataset.score===b.dataset.saveMark);const score=Number(inp?.value);
      if(!Number.isInteger(score)||score<0||score>100){toast('Use a whole number between 0 and 100.',true);return;}
      try{await post('/api/marks',{learnerId:student.id,subject:b.dataset.saveMark,score});await reload();toast('Learner mark saved.');}catch(e){toast(e.message,true);}
    }));
    $('newMarkForm')?.addEventListener('submit',async e=>{e.preventDefault();const f=new FormData(e.target),student=currentLearner();try{await post('/api/marks',{learnerId:student.id,subject:String(f.get('subject')).trim(),score:Number(f.get('score'))});await reload();toast('Subject result saved.');}catch(err){toast(err.message,true);}});
    $('eventForm')?.addEventListener('submit',async e=>{e.preventDefault();const f=new FormData(e.target);try{const payload={title:String(f.get('title')).trim(),description:String(f.get('description')||''),date:String(f.get('date')),grade:String(f.get('grade')),category:String(f.get('category')),time:String(f.get('time')||'')};if(editingEvent){await mutation('PUT',`/api/extended/events/${editingEvent}`,payload);editingEvent=null;}else await post('/api/events',payload);await reload();toast('School event saved.');}catch(err){toast(err.message,true);}});
    $('announcementForm')?.addEventListener('submit',async e=>{e.preventDefault();const f=new FormData(e.target);try{const payload={title:String(f.get('title')).trim(),body:String(f.get('body')).trim(),grade:f.get('grade'),priority:f.get('priority')};if(editingAnnouncement){await mutation('PUT',`/api/extended/announcements/${editingAnnouncement}`,{announcement:payload,status:f.get('status')});editingAnnouncement=null;}else await post('/api/announcements',payload);await reload();toast('Saved');}catch(err){toast(err.message,true);}});
    document.querySelectorAll('[data-thread]').forEach(b=>b.addEventListener('click',async()=>{selectedGuardian=b.dataset.thread;render();if(extended)try{await post(`/api/extended/messages/${selectedGuardian}/read`,{});await loadExtension();}catch(e){toast(e.message,true);}}));
    $('messageForm')?.addEventListener('submit',async e=>{e.preventDefault();const f=new FormData(e.target);try{await post('/api/messages',{guardianId:selectedGuardian,text:String(f.get('text')).trim()});await reload();toast('Message sent to parent.');}catch(err){toast(err.message,true);}});
    document.querySelectorAll('[data-read]').forEach(b=>b.addEventListener('click',async()=>{try{await post(`/api/alerts/${encodeURIComponent(b.dataset.read)}/read`,{});await reload();}catch(err){toast(err.message,true);}}));
    $('printReport')?.addEventListener('click',()=>window.print());


    for(const id of ['insightFrom','insightTo','insightGrade','insightClass']){
      $(id)?.addEventListener('change',e=>{const val=e.target.value;
        if(id==='insightFrom')insightFrom=val;else if(id==='insightTo')insightTo=val;else if(id==='insightGrade'){insightGrade=val;insightClass='all';}else insightClass=val;insightMetrics=null;render();refreshInsights();});
    }
    $('clearInsights')?.addEventListener('click',()=>{insightFrom='';insightTo='';insightGrade='all';insightClass='all';insightMetrics=null;render();refreshInsights();});
    document.querySelectorAll('[data-report-preset]').forEach(b=>b.addEventListener('click',()=>{const key=b.dataset.reportPreset,d=new Date();
      if(key==='today')insightFrom=today();else if(key==='year')insightFrom=String(d.getFullYear())+'-01-01';else{d.setDate(d.getDate()-(key==='week'?6:29));const offset=d.getTimezoneOffset()*60000;insightFrom=new Date(d.getTime()-offset).toISOString().slice(0,10);}
      insightTo=today();insightMetrics=null;render();refreshInsights();}));
    $('printInsights')?.addEventListener('click',()=>window.print());
    $('exportAttendanceCsv')?.addEventListener('click',()=>{
      const rows=[['Class','Grade','Attendance entries','Present','Absent','Late','Attendance rate'],
       ...(insightMetrics?.classes||[]).map(r=>[r.className,r.grade,r.total,r.present,r.absent,r.late,Number(r.total)?Math.round(Number(r.present)/Number(r.total)*100)+'%':'—'])];
      const csv='\uFEFF'+rows.map(r=>r.map(v=>'"'+String(v).replace(/"/g,'""')+'"').join(',')).join('\r\n');
      const url=URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'}));
      const a=document.createElement('a');a.href=url;a.download='kagisho-class-attendance-'+today()+'.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),5000);
    });
    // V6: requests are always reviewed by the authenticated school administrator.
    $('learnerBirthdateForm')?.addEventListener('submit',async e=>{
      e.preventDefault();const f=new FormData(e.target);
      try{await mutation('PUT',`/api/extended/learners/${encodeURIComponent(String(f.get('learnerId')))}/birthdate`,
        {date:String(f.get('date'))});await refreshGuardianRequests();render();toast('Saved');}
      catch(err){toast(err.message,true);}
    });
    document.querySelectorAll('[data-guardian-review]').forEach(b=>b.addEventListener('click',async()=>{
      const approve=b.dataset.approve==='true';
      if(!confirm(approve?
        'Have you independently verified this person’s identity and guardianship? The name and DOB must match one learner. Approve access?':
        'Reject this parent request?'))return;
      b.disabled=true;
      try{
        const requestId=b.dataset.guardianReview;
        const result=await post(`/api/extended/guardian-requests/${encodeURIComponent(requestId)}/review`,
          {approve,note:''});
        const expected=approve?'approved':'rejected';
        if(result?.status!==expected || (approve&&!result?.learnerId))
          throw new Error('The school did not confirm this request was saved. Please refresh and verify the status.');
        await reload();await refreshAdmin();
        const confirmed=(guardianReviews?.requests||[]).find(r=>r.id===requestId);
        if(!confirmed || confirmed.status!==expected)
          throw new Error('The review was processed, but its latest status could not be confirmed. Refresh the request list.');
        toast(approve?'Approved — learner linked.':'Request rejected.');
      }catch(err){toast(err.message,true);}
      finally{b.disabled=false;}
    }));
    // V5 features: all data mutations go to ASP.NET then Supabase RLS.
    $('learnerSearch')?.addEventListener('input',e=>{const q=e.target.value.toLowerCase();document.querySelectorAll('[data-learner-search]').forEach(el=>el.hidden=!el.dataset.learnerSearch.includes(q));});
    $('eventSearch')?.addEventListener('input',e=>{const q=e.target.value.toLowerCase();document.querySelectorAll('[data-event-search]').forEach(el=>el.hidden=!el.dataset.eventSearch.includes(q));});
    $('auditSearch')?.addEventListener('input',e=>{const q=e.target.value.toLowerCase();document.querySelectorAll('[data-audit-search]').forEach(el=>el.hidden=!el.dataset.auditSearch.includes(q));});
    $('docSearch')?.addEventListener('input',e=>{const q=e.target.value.toLowerCase();document.querySelectorAll('[data-doc-search]').forEach(el=>el.hidden=!el.dataset.docSearch.includes(q));});
    document.querySelectorAll('[data-edit-ann]').forEach(b=>b.addEventListener('click',()=>{editingAnnouncement=b.dataset.editAnn;render();window.scrollTo(0,0);}));
    $('cancelAnnouncement')?.addEventListener('click',()=>{editingAnnouncement=null;render();});
    document.querySelectorAll('[data-ann-status]').forEach(b=>b.addEventListener('click',async()=>{if(!confirm(`Change announcement to ${b.dataset.next}?`))return;try{await mutation('PATCH',`/api/extended/announcements/${b.dataset.annStatus}/status`,{status:b.dataset.next});await reload();toast('Announcement status updated.');}catch(e){toast(e.message,true);}}));
    document.querySelectorAll('[data-delete-ann]').forEach(b=>b.addEventListener('click',async()=>{if(!confirm('Permanently delete this announcement? This cannot be undone.'))return;try{await destroy(`/api/extended/announcements/${b.dataset.deleteAnn}`);await reload();toast('Announcement deleted.');}catch(e){toast(e.message,true);}}));
    document.querySelectorAll('[data-edit-event]').forEach(b=>b.addEventListener('click',()=>{editingEvent=b.dataset.editEvent;render();window.scrollTo(0,0);}));
    $('cancelEvent')?.addEventListener('click',()=>{editingEvent=null;render();});
    document.querySelectorAll('[data-delete-event]').forEach(b=>b.addEventListener('click',async()=>{if(!confirm('Permanently delete this calendar event?'))return;try{await destroy(`/api/extended/events/${b.dataset.deleteEvent}`);await reload();toast('Calendar event deleted.');}catch(e){toast(e.message,true);}}));
    document.querySelectorAll('[data-edit-learner]').forEach(b=>b.addEventListener('click',()=>{editingLearner=b.dataset.editLearner;render();window.scrollTo(0,0);}));
    $('cancelLearner')?.addEventListener('click',()=>{editingLearner=null;render();});
    $('editLearnerForm')?.addEventListener('submit',async e=>{e.preventDefault();const f=new FormData(e.target);try{await mutation('PUT',`/api/extended/learners/${editingLearner}`,{name:String(f.get('name')),classId:String(f.get('classId')),active:f.has('active'),admissionNumber:String(f.get('admissionNumber')||'')});editingLearner=null;await reload();await refreshAdmin();toast('Learner updated. UUID unchanged.');}catch(err){toast(err.message,true);}});
    document.querySelectorAll('[data-unlink-learner]').forEach(b=>b.addEventListener('click',async()=>{if(!confirm('Remove this verified parent–learner relationship? The parent will lose access to this learner.'))return;try{await destroy(`/api/extended/learners/${b.dataset.unlinkLearner}/guardians/${b.dataset.unlinkParent}`);await reload();await refreshAdmin();toast('Guardian link removed.');}catch(err){toast(err.message,true);}}));
    $('documentForm')?.addEventListener('submit',async e=>{e.preventDefault();const btn=e.target.querySelector('button');btn.disabled=true;const f=new FormData(e.target);f.set('published',f.has('published')?'true':'false');try{await call('/api/extended/documents/upload',{method:'POST',body:f});await reload();toast('Document uploaded securely.');}catch(err){toast(err.message,true);btn.disabled=false;}});
    document.querySelectorAll('[data-doc-status]').forEach(b=>b.addEventListener('click',async()=>{try{await mutation('PATCH',`/api/extended/documents/${b.dataset.docStatus}/publication`,{published:b.dataset.publish==='true'});await reload();toast('Document publication updated.');}catch(err){toast(err.message,true);}}));
    document.querySelectorAll('[data-delete-doc]').forEach(b=>b.addEventListener('click',async()=>{if(!confirm('Permanently delete this document and its file?'))return;try{await destroy(`/api/extended/documents/${b.dataset.deleteDoc}`);await reload();toast('Document removed.');}catch(err){toast(err.message,true);}}));
    $('termForm')?.addEventListener('submit',async e=>{e.preventDefault();const f=new FormData(e.target);try{await post('/api/extended/terms',{year:Number(f.get('year')),term:Number(f.get('term')),start:f.get('start'),end:f.get('end')});await reload();toast('Term saved.');}catch(err){toast(err.message,true);}});
    $('createReportForm')?.addEventListener('submit',async e=>{e.preventDefault();const f=new FormData(e.target);try{const r=await post('/api/extended/reports',{learnerId:f.get('learnerId'),termId:f.get('termId'),comment:String(f.get('comment')||'')});selectedReport=r[0]?.id;await reload();toast('Draft report card created.');}catch(err){toast(err.message,true);}});
    $('reportSelector')?.addEventListener('change',e=>{selectedReport=e.target.value;render();});
    $('reportMarkForm')?.addEventListener('submit',async e=>{e.preventDefault();const f=new FormData(e.target);try{await post(`/api/extended/reports/${selectedReport}/marks`,{subject:String(f.get('subject')),percentage:Number(f.get('percentage'))});await reload();toast('Report mark saved.');}catch(err){toast(err.message,true);}});
    $('reportStatusForm')?.addEventListener('submit',async e=>{e.preventDefault();const b=e.submitter;if(!b?.dataset.reportPublish)return;if(!confirm(b.dataset.reportPublish==='true'?'Publish this report card?':'Unpublish this report card for correction?'))return;const f=new FormData(e.target);try{await mutation('PATCH',`/api/extended/reports/${selectedReport}/publication`,{published:b.dataset.reportPublish==='true',comment:String(f.get('comment')||'')});await reload();toast('Report status saved.');}catch(err){toast(err.message,true);}});
    $('printReportCard')?.addEventListener('click',()=>{const el=$('reportPrint');if(!el)return;const win=window.open('','_blank','width=850,height=900');if(!win){toast('Allow pop-ups to print the report.',true);return;}win.document.write(`<html><head><title>Academic report</title><style>body{font:16px Arial;margin:48px;color:#123F6A}table{width:100%;border-collapse:collapse;margin:20px 0}th,td{padding:12px;border:1px solid #C2E3F6;text-align:left}h2{margin-top:28px}.report-heading{display:flex;justify-content:space-between;border-bottom:3px solid #087FC0;padding-bottom:15px}</style></head><body>${el.innerHTML}</body></html>`);win.document.close();win.focus();win.print();});
    document.querySelectorAll('[data-view-message]').forEach(b=>b.addEventListener('click',()=>{selectedGuardian=b.dataset.viewMessage;goto('messages');}));
    for(const [formId,url,make] of [
      ['classForm','/api/admin/classes',f=>({name:String(f.get('name')).trim(),grade:Number(f.get('grade'))})],
      ['learnerForm','/api/admin/learners',f=>({name:String(f.get('name')).trim(),classId:String(f.get('classId')),admissionNumber:String(f.get('admissionNumber')).trim(),birthDate:String(f.get('birthDate'))})],
      ['guardianLinkForm','/api/admin/link-guardian',f=>({userId:String(f.get('userId')),learnerId:String(f.get('learnerId'))})],
      ['assignClassForm','/api/admin/assign-teacher',f=>({userId:String(f.get('userId')),classId:String(f.get('classId'))})]
    ]){
      $(formId)?.addEventListener('submit',async e=>{e.preventDefault();const button=e.target.querySelector('button[type="submit"],button');if(button)button.disabled=true;
        try{await post(url,make(new FormData(e.target)));await reload();await refreshAdmin();toast('Saved');}
        catch(err){toast(err.message,true);if(button)button.disabled=false;}
      });
    }
    $('inviteStaffForm')?.addEventListener('submit',async e=>{
      e.preventDefault();const f=new FormData(e.target);const btn=e.target.querySelector('button[type=submit]');btn.disabled=true;
      try{await post('/api/admin/staff',{name:String(f.get('name')).trim(),email:String(f.get('email')).trim(),role:String(f.get('role'))});toast('An invitation has been emailed to the new staff member.');await refreshStaff();}
      catch(err){toast(err.message,true);btn.disabled=false;}
    });
    document.querySelectorAll('[data-set-active]').forEach(b=>b.addEventListener('click',async()=>{
      const next=b.dataset.active==='true';
      if(!confirm(`${next?'Activate':'Deactivate'} this staff account?`))return;
      try{await post(`/api/admin/staff/${encodeURIComponent(b.dataset.setActive)}/status`,{active:next});toast(`Staff account ${next?'activated':'deactivated'}.`);await refreshStaff();}
      catch(err){toast(err.message,true);}
    }));
    if($('thread'))$('thread').scrollTop=$('thread').scrollHeight;
  }
  reload().then(()=>{restoreDraft();render();}).catch(e=>{$('app').innerHTML=`<div class="loading-screen"><h2>Unable to open the school portal</h2><p>${esc(e.message)}</p><a class="button primary" href="/login">Return to sign in</a></div>`;});
})();
