let createNanoEvents=()=>({emit(e,...t){for(let s=this.events[e]||[],n=0,h=s.length;n<h;n++)s[n](...t)},events:{},on(e,t){(this.events[e]||=[]).push(t);return()=>{this.events[e]=this.events[e]?.filter((e=>t!==e))}}});export{createNanoEvents};

