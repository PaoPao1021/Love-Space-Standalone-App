// Local-only visual fixture server. Never use this as an application backend.
// Run after `cd app && flutter build web`: node scripts/preview-ui.mjs
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../app/build/web/', import.meta.url));
const user = {_id:'preview-a', username:'preview', nickName:'小鹿', avatarUrl:'', coupleId:'preview-couple', role:'creator'};
const partner = {...user, _id:'preview-b', nickName:'小熊', role:'partner'};
const moments = [{_id:'preview-memory', author:user._id, title:'一起散步的傍晚', content:'绕了一点远路，刚好多陪你一会儿。', images:[], tags:['日常'], createdAt:'2026-09-09T18:30:00', eventDate:'2026-09-09'}];
let answer = null;
function fixture(url, payload) {
  const action = payload.action;
  if (url.includes('/auth/')) return {accessToken:'local-preview-only', refreshToken:'local-preview-only', userInfo:user};
  if (url.endsWith('/couple')) return {couple:{startDate:'2024-05-20'}, user, partner};
  if (url.endsWith('/daily-question')) {
    if (action === 'submit') answer = payload.data?.answer ?? null;
    return {question:'今天，有哪个瞬间让你特别想和我分享？', category:'日常连接', myAnswer:answer, partnerAnswered:true, bothAnswered:!!answer, partnerAnswer:answer ? '回家的路上看见了很好看的晚霞。' : null};
  }
  if (url.endsWith('/anniversary')) return {list:[{_id:'preview-date', name:'我们的纪念日', date:'2024-05-20', type:'love', isRepeat:true, isTop:true, note:''}]};
  if (url.endsWith('/mood')) return action === 'getCalendar' ? {list:[]} : {data:{_id:'preview-mood', moodType:action === 'getToday' ? 'happy' : 'love', content:'今天也有被爱着的感觉', visibility:'both', date:'2026-09-10'}};
  if (url.endsWith('/moments')) return action === 'random' || action === 'get' ? {data:moments[0]} : {list:moments,hasMore:false};
  if (url.endsWith('/notification')) return {list:[], unreadCount:0};
  if (url.endsWith('/points')) return {myScore:640,partnerScore:560,list:[]};
  if (url.endsWith('/fitness')) return {teamProgress:60,myStats:{workouts:3,minutes:90,checkinDays:3},partnerStats:{workouts:2},myGoal:{configured:true,goalType:'fat-loss',weeklyWorkouts:3,dailySteps:8000,privacy:'trend'},partnerCheckedIn:true,challenges:[],challengePresets:[]};
  if (url.endsWith('/monthly-report')) return {report:{year:2026,month:9,connectionScore:60,mood:{together:6},questions:{together:4},moments:{count:3,photos:0},points:{total:1200}}};
  if (url.endsWith('/album')) return {list:[{_id:'preview-album',name:'日常',photoCount:0}],total:0,hasMore:false};
  return {list:[],hasMore:false};
}

const types = {'.html':'text/html; charset=utf-8','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.ttf':'font/ttf','.otf':'font/otf'};
http.createServer(async (req,res) => {
  try {
    const url = new URL(req.url,'http://127.0.0.1');
    if (url.pathname.startsWith('/api/')) {
      let body = ''; for await (const chunk of req) body += chunk;
      res.writeHead(200,{'Content-Type':'application/json','Cache-Control':'no-store'});
      res.end(JSON.stringify({code:0,...fixture(url.pathname,body ? JSON.parse(body) : {})})); return;
    }
    const filename = path.resolve(root, '.' + decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname));
    if (!filename.startsWith(root)) {res.writeHead(403);res.end();return;}
    const data = await readFile(filename);
    res.writeHead(200,{'Content-Type':types[path.extname(filename)] ?? 'application/octet-stream','Cache-Control':'no-store'});res.end(data);
  } catch {res.writeHead(404);res.end('Not found');}
}).listen(4175,'127.0.0.1',() => console.log('UI fixture preview (fictional data only): http://127.0.0.1:4175'));
