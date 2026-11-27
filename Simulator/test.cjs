const assert=require('node:assert/strict');const {evaluate:e}=require('./pacing.js');
const behind=e(5000,1800,2000,780,1000/370);assert.equal(behind.state,'faster');assert.equal(behind.required,340);
assert.equal(e(5000,1800,2000,660,1000/420).state,'faster');
assert.equal(e(5000,1800,2000,660,1000/330).state,'ease');assert.equal(e(5000,1800,2000,660,1000/330).required,380);
assert.equal(e(5000,1800,2000,720,1000/360).state,'hold');
assert.equal(e(5000,1800,5000,1805,3).state,'complete');assert.equal(e(5000,1800,4900,1800,3).state,'expired');
assert.equal(e(5000,1800,500,180,0).state,'waiting');assert.equal(e(5000,1800,500,180,3,false).projected,null);
assert.throws(()=>e(0,1800,0,0,3));assert.throws(()=>e(5000,NaN,0,0,3));
for(let d=0;d<5000;d+=50){const r=e(5000,1800,d,d*0.36,1000/360);assert.equal(r.state,'hold');assert.ok(Number.isFinite(r.required));}
console.log('Pacing engine checks passed, including 100 steady-pace positions.');
