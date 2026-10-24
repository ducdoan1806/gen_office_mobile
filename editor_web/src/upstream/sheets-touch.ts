// Touch adapter for the original desktop grid. Desktop mouse/pen events stay native.
export function installSheetsTouch() {
    let gesture:any, raf=0, pendingX=0,pendingY=0,lastTap:any;
    const fingers=new Set<number>();
    const stop=()=>{cancelAnimationFrame(raf);raf=0;pendingX=pendingY=0;};
    const wheel=(_g:any,x:number,y:number)=>{
        const api=(window as any).genOfficeSheets;
        const zoom=api?.getActiveWorkbook()?.getActiveSheet()?.getZoom?.() || 1;
        // Use the same bounded scroll command as the native wheel controller.
        // A touch pan must work before a mouse click has focused the grid.
        void api?.executeCommand('sheet.command.set-scroll-relative',{offsetX:x/zoom,offsetY:y/zoom});
    };
    const mouse=(g:any,type:string,x=g.x,y=g.y)=>{
        const rect=g.target.getBoundingClientRect();
        const event=new PointerEvent(type,{
            bubbles:true,cancelable:true,pointerType:'mouse',pointerId:1,isPrimary:true,
            clientX:x,clientY:y,button:0,buttons:type==='pointerup'||type==='pointercancel'?0:1,
        });
        // Android WebView can apply its page scale again when deriving offsets
        // for synthetic events. Univer picks cells using canvas-local CSS pixels.
        Object.defineProperties(event,{
            offsetX:{value:x-rect.left},offsetY:{value:y-rect.top},
        });
        return g.target.dispatchEvent(event);
    };
    const consume=(e:PointerEvent)=>{e.preventDefault();e.stopImmediatePropagation();};
    const cancel=()=>{if(gesture){clearTimeout(gesture.timer);if(gesture.selecting)mouse(gesture,'pointercancel');}gesture=undefined;stop();lastTap=undefined;};
    const down=(e:PointerEvent)=>{
        if(e.pointerType!=='touch')return;
        const canvas=(e.target as HTMLElement)?.closest?.('#univer-container canvas[id^="univer-sheet-main-canvas_"]') as HTMLCanvasElement|null;
        if(!canvas)return;
        const rect=canvas.getBoundingClientRect();
        if(!gesture&&(e.clientX-rect.left<46||e.clientY-rect.top<30))return;
        consume(e);fingers.add(e.pointerId);stop();
        if(fingers.size>1){cancel();return;}
        const g=gesture={id:e.pointerId,target:canvas,x:e.clientX,y:e.clientY,lastX:e.clientX,lastY:e.clientY,time:performance.now(),vx:0,vy:0,axis:'',selecting:false};
        try { canvas.setPointerCapture(e.pointerId); } catch { /* Synthetic QA pointers have no native capture. */ }
        g.timer=setTimeout(()=>{if(gesture!==g||g.axis)return;g.selecting=true;lastTap=undefined;mouse(g,'pointerdown');},400);
    };
    const move=(e:PointerEvent)=>{
        if(e.pointerType!=='touch'||!fingers.has(e.pointerId))return;
        consume(e);const g=gesture;if(!g||g.id!==e.pointerId)return;
        if(g.selecting){mouse(g,'pointermove',e.clientX,e.clientY);return;}
        const dx=e.clientX-g.x,dy=e.clientY-g.y;
        if(!g.axis&&Math.hypot(dx,dy)<8)return;
        if(!g.axis){g.axis=Math.abs(dx)>Math.abs(dy)?'x':'y';clearTimeout(g.timer);lastTap=undefined;}
        const now=performance.now(),dt=Math.max(8,now-g.time);
        const x=g.axis==='x'?g.lastX-e.clientX:0,y=g.axis==='y'?g.lastY-e.clientY:0;
        g.vx=Math.max(-3,Math.min(3,x/dt));g.vy=Math.max(-3,Math.min(3,y/dt));
        g.lastX=e.clientX;g.lastY=e.clientY;g.time=now;pendingX+=x;pendingY+=y;
        if(!raf)raf=requestAnimationFrame(()=>{raf=0;wheel(g,pendingX,pendingY);pendingX=pendingY=0;});
    };
    const up=(e:PointerEvent)=>{
        if(e.pointerType!=='touch'||!fingers.delete(e.pointerId))return;
        consume(e);const g=gesture;if(!g||g.id!==e.pointerId)return;
        clearTimeout(g.timer);gesture=undefined;
        if(e.type==='pointercancel'){if(g.selecting)mouse(g,'pointercancel');stop();return;}
        if(g.selecting){mouse(g,'pointerup',e.clientX,e.clientY);return;}
        if(!g.axis){mouse(g,'pointerdown');mouse(g,'pointerup');
            const now=performance.now();if(lastTap&&now-lastTap.time<350&&Math.hypot(g.x-lastTap.x,g.y-lastTap.y)<24){
                g.target.dispatchEvent(new MouseEvent('dblclick',{bubbles:true,cancelable:true,clientX:g.x,clientY:g.y,button:0,detail:2}));lastTap=undefined;
            }else lastTap={time:now,x:g.x,y:g.y};return;
        }
        if(raf){cancelAnimationFrame(raf);raf=0;wheel(g,pendingX,pendingY);pendingX=pendingY=0;}
        if(performance.now()-g.time>90)return;
        let previous=performance.now(),elapsed=0;
        const coast=(now:number)=>{const dt=Math.min(32,now-previous);previous=now;elapsed+=dt;
            wheel(g,g.vx*dt,g.vy*dt);const decay=Math.pow(.92,dt/16);g.vx*=decay;g.vy*=decay;
            if(elapsed<1200&&Math.hypot(g.vx,g.vy)>.025)raf=requestAnimationFrame(coast);else raf=0;};
        raf=requestAnimationFrame(coast);
    };
    document.addEventListener('pointerdown',down,{capture:true,passive:false});
    document.addEventListener('pointermove',move,{capture:true,passive:false});
    document.addEventListener('pointerup',up,{capture:true,passive:false});
    document.addEventListener('pointercancel',up,{capture:true,passive:false});
    window.addEventListener('blur',()=>{cancel();fingers.clear();});
    document.addEventListener('visibilitychange',()=>{if(document.hidden){cancel();fingers.clear();}});
}
