/* SI units internally; required pace is seconds per kilometer. */
(function(root){
 function evaluate(goalMeters,goalSeconds,distance,elapsed,speed,valid=true){
  if (![goalMeters,goalSeconds,distance,elapsed,speed].every(Number.isFinite)||goalMeters<=0||goalSeconds<=0||distance<0||elapsed<0||speed<0) throw Error('Invalid pacing input');
  const remaining=Math.max(0,goalMeters-distance),left=goalSeconds-elapsed;
  if(remaining===0)return {state:'complete',required:null,projected:elapsed,buffer:goalSeconds-elapsed};
  if(left<=0)return {state:'expired',required:null,projected:speed>0?elapsed+remaining/speed:null,buffer:null};
  const required=left/remaining*1000,projected=speed>0?elapsed+remaining/speed:null;
  if(!valid||speed===0)return {state:'waiting',required,projected:null,buffer:null};
  const buffer=goalSeconds-projected,tolerance=Math.max(8,Math.min(25,left*.015));
  return {state:buffer < -tolerance?'faster':buffer > tolerance?'ease':'hold',required,projected,buffer};
 }
 if(typeof module!=='undefined')module.exports={evaluate};else root.Pacing={evaluate};
})(globalThis);
