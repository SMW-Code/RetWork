// 프로젝트 폴더의 test*.jpg/png 를 한 번에: Vision 호출 → EXIF 회전보정(좌표) → table-proto.html의 parseTable 로 파싱
// 사용:  node _batchtest.js            (test*.* 전부)
//        node _batchtest.js test2.jpg  (특정 파일)
const fs=require('fs');

// --- table-proto.html 에서 실제 파서 추출 (브라우저와 동일 로직) ---
const html=fs.readFileSync('public/table-proto.html','utf8');
function grab(re){const i=html.search(re);let s=html.indexOf('{',i),depth=0,j=s;
  for(;j<html.length;j++){if(html[j]==='{')depth++;else if(html[j]==='}'){if(--depth===0){j++;break;}}}return html.slice(i,j);}
var metaLine=html.match(/var META_NAME=[^\n]*/)[0];
eval([metaLine,grab(/function toYen\(/),grab(/function cleanName\(/),grab(/function extractWords\(/),grab(/function parseTable\(/)].join('\n'));

// --- JPEG 크기 + EXIF orientation ---
function jpegMeta(buf){
  const b=new Uint8Array(buf); let W=0,H=0,ori=1,i=2;
  while(i<b.length){ if(b[i]!==0xFF){i++;continue;} const m=b[i+1];
    if(m>=0xC0&&m<=0xCF&&m!==0xC4&&m!==0xC8&&m!==0xCC){H=(b[i+5]<<8)|b[i+6];W=(b[i+7]<<8)|b[i+8];break;}
    if(m===0xD8||m===0xD9){i+=2;continue;} i+=2+((b[i+2]<<8)|b[i+3]); }
  for(let k=0;k<b.length-6;k++){ if(b[k]===0x45&&b[k+1]===0x78&&b[k+2]===0x69&&b[k+3]===0x66&&b[k+4]===0&&b[k+5]===0){
    const t=k+6, le=b[t]===0x49;
    const r16=o=>le?(b[o]|b[o+1]<<8):(b[o]<<8|b[o+1]);
    const r32=o=>le?(b[o]|b[o+1]<<8|b[o+2]<<16|b[o+3]<<24):(b[o]<<24|b[o+1]<<16|b[o+2]<<8|b[o+3]);
    const ifd=t+r32(t+4),n=r16(ifd);
    for(let j=0;j<n;j++){const e=ifd+2+j*12; if(r16(e)===0x0112){ori=r16(e+8);break;}} break; } }
  return {W,H,ori};
}
// orientation 에 맞춰 좌표를 똑바로 회전 (브라우저 캔버스 회전과 등가)
function rotateVerts(v,W,H,ori){
  return v.map(p=>{const x=p.x||0,y=p.y||0;switch(ori){
    case 3: return {x:W-1-x,y:H-1-y};
    case 6: return {x:H-1-y,y:x};
    case 8: return {x:y,y:W-1-x};
    default:return {x,y};}});
}

async function run(file){
  const buf=fs.readFileSync(file);
  const {W,H,ori}=jpegMeta(buf.buffer.slice(buf.byteOffset,buf.byteOffset+buf.length));
  const b64=buf.toString('base64');
  const res=await fetch('http://localhost:3000/api/vision',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({base64Image:b64})});
  const d=await res.json();
  if(d.error){console.log('  ❌ Vision error:',d.error.message);return;}
  const ann=(d.responses[0].textAnnotations||[]).slice(1)
    .map(a=>({description:a.description,boundingPoly:{vertices:rotateVerts(a.boundingPoly.vertices,W,H,ori)}}));
  const r=parseTable(ann);
  console.log('\n=== '+file+'  (EXIF orientation='+ori+', '+W+'x'+H+') ===');
  r.items.forEach(it=>console.log('  '+it.name+'  x'+it.qty+'  ¥'+it.price.toLocaleString()));
  console.log('  품목수:'+r.items.length+'  sum:¥'+r.sum.toLocaleString()+'  小計:¥'+r.subtotal.toLocaleString()+'  合計:¥'+r.total.toLocaleString());
  console.log('  검증:'+(r.ok?'✅ 통과':'❌ 불일치 (차액 ¥'+Math.abs((r.subtotal||r.total)-r.sum).toLocaleString()+')'));
}

(async()=>{
  let files=process.argv.slice(2);
  if(!files.length) files=fs.readdirSync('.').filter(f=>/^test.*\.(jpe?g|png)$/i.test(f)).sort();
  if(!files.length){console.log('test*.jpg/png 파일이 없습니다.');return;}
  for(const f of files) await run(f);
})();
