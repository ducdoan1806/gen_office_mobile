import {describe,it,expect} from 'vitest';
import {AiEditGuard} from '../src/upstream/ai-edits';
describe('AI edits',()=>{
 it('rejects document conflict, unknown ids, duplicates and changed originals',()=>{
   const guard=new AiEditGuard(), c=guard.capture('v1',[{id:'a',label:'A',text:'old'}],'selection');
   const args={revision:c.revision,changes:[{id:'a',before:'old',after:'new'}]};
   expect(guard.validate(args,'v1')).toHaveLength(1);
   expect(guard.capture('v1',[{id:'a',label:'A',text:'old'}],'selection').revision).toBe(c.revision);
   expect(guard.validate(args,'v1')).toHaveLength(1);
   expect(()=>guard.validate(args,'v2')).toThrow('đã thay đổi');
   expect(()=>guard.validate({...args,changes:[{id:'other',before:'old',after:'new'}]},'v1')).toThrow();
   expect(()=>guard.validate({...args,changes:[...args.changes,...args.changes]},'v1')).toThrow();
   expect(()=>guard.validate({...args,changes:[{id:'a',before:'stale',after:'new'}]},'v1')).toThrow();
   guard.invalidate();expect(()=>guard.validate(args,'v1')).toThrow();
 });
 it('rejects too much context without truncating silently',()=>{
   expect(()=>new AiEditGuard().capture('v',[{id:'a',label:'A',text:'x'.repeat(60000)}],'doc')).toThrow('quá lớn');
 });
});
