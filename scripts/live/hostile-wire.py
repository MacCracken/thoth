#!/usr/bin/env python3
"""hostile-wire.py — a stub gateway that answers thoth with malformed and hostile responses, one scenario per run.

The 2026-11-05 audit's wire kit: SSE frames, raw HTTP (Content-Length and chunk-size attacks, 2 MB headers) and blocking
bodies, each driven through a real `thoth -p` under a throwaway HOME and project. A scenario fails on a crash or a hang
(`CRASH`) or when thoth then POSTs invalid JSON (`BADREQ`). Local only: it listens on 127.0.0.1 and reaches nothing else.

Usage: hostile-wire.py BIN [NAME-FILTER]      BIN = the thoth under test, on this host
Env:   THOTH_HOSTILE_PORT (default 18741) · THOTH_HOSTILE_DIR (default a new temp dir)
       THOTH_HOSTILE_PAIRS=1 also prints each round's tool-call ids against its results
Exit:  0 when no scenario was flagged, 1 otherwise.
"""
import socket, threading, json, subprocess, os, sys, time, signal, re, tempfile
if len(sys.argv) < 2:
    sys.exit(__doc__)
BIN=os.path.abspath(sys.argv[1])
A=os.environ.get('THOTH_HOSTILE_DIR') or tempfile.mkdtemp(prefix='thoth-hostile.')
PORT=int(os.environ.get('THOTH_HOSTILE_PORT','18741'))
H=A+'/lab/fz/home'; P=A+'/lab/fz/proj'
os.makedirs(H+'/.thoth',exist_ok=True); os.makedirs(P,exist_ok=True)
open(P+'/a.txt','w').write('hello\n')
def cfg(stream):
    open(H+'/.thoth/config.cyml','w').write(f'''[hoosh]
url = "http://127.0.0.1:{PORT}"
model = "m"
stream = {"true" if stream else "false"}
timeout_ms = 2500
---
''')
J=lambda o: json.dumps(o).encode()
def D(**k): return J({"choices":[{"delta":k}]})
TC=lambda **k: D(tool_calls=[k])
FN=lambda n='read_file',a='{"path":"a.txt"}': {"name":n,"arguments":a}
sse=lambda frames,tail=b'data: [DONE]\n\n': b''.join(b'data: '+f+b'\n\n' for f in frames)+tail
S={}  # name -> raw body bytes for stream=true (wrapped with content-length)
def add(n,*fr): S[n]=sse(list(fr))
add('choices_int',J({"choices":5})); add('choices_int_arr',J({"choices":[5]})); add('choices_null',J({"choices":None}))
add('choices_str',J({"choices":"x"})); add('top_arr',b'[1,2]'); add('top_int',b'5'); add('top_null',b'null'); add('top_str',b'"x"')
add('delta_int',J({"choices":[{"delta":7}]})); add('delta_null',J({"choices":[{"delta":None}]})); add('delta_arr',J({"choices":[{"delta":[1]}]}))
add('content_int',D(content=123)); add('content_null',D(content=None)); add('content_obj',D(content={"a":1})); add('content_arr',D(content=[1]))
add('reason_int',D(reasoning_content=1)); add('reason_obj',D(reasoning_content={}))
add('tc_str',D(tool_calls="x")); add('tc_int',D(tool_calls=5)); add('tc_mixed',D(tool_calls=[5,None,"x",[1],{}]))
for v in [-1,3.5,1e308,"3",None,True,9223372036854775807,31,32,33]:
    add('idx_%r'%(v,),TC(index=v,id='i',function=FN()))
add('idx_big',b'{"choices":[{"delta":{"tool_calls":[{"index":99999999999999999999999,"id":"i","function":{"name":"read_file","arguments":"{}"}}]}}]}')
add('idx_1e400',b'{"choices":[{"delta":{"tool_calls":[{"index":1e400,"id":"i","function":{"name":"read_file","arguments":"{}"}}]}}]}')
add('idx_neg_float',b'{"choices":[{"delta":{"tool_calls":[{"index":-1e30,"id":"i","function":{"name":"read_file","arguments":"{}"}}]}}]}')
add('fn_int',TC(index=0,id='i',function=5)); add('fn_null',TC(index=0,id='i',function=None)); add('fn_name_int',TC(index=0,id='i',function={"name":5,"arguments":"{}"}))
add('fn_args_int',TC(index=0,id='i',function={"name":"read_file","arguments":5})); add('fn_args_obj',TC(index=0,id='i',function={"name":"read_file","arguments":{"path":"a.txt"}}))
add('id_int',TC(index=0,id=5,function=FN()))
add('id_huge',TC(index=0,id='x'*1000000,function=FN())); add('name_huge',TC(index=0,id='i',function=FN(n='y'*1000000)))
add('args_huge',TC(index=0,id='i',function=FN(a='z'*200000)))
add('args_frag_over',*[TC(index=0,id='i' if i==0 else None,function={"name":"read_file" if i==0 else None,"arguments":"a"*5000}) for i in range(5)])
add('dup_idx',TC(index=0,id='a',function=FN('read_file','{"path":"a.txt"}')),TC(index=0,id='b',function=FN('shell','{"command":"id"}')))
add('dup_key',b'{"choices":[{"delta":{"content":"a","content":"b"}}]}')
add('nul_content',D(content="a\u0000b")); add('nul_name',TC(index=0,id='i',function=FN(n='read_file\u0000evil')))
add('nul_args',TC(index=0,id='i',function=FN(a='{"path":"a.txt"}\u0000garbage'))); add('nul_id',TC(index=0,id='i\u0000j',function=FN()))
add('esc_name',TC(index=0,id='i',function=FN(n='\u001b[2Jx'))); add('esc_id',TC(index=0,id='\u001b]0;x\u0007',function=FN()))
add('quote_id',TC(index=0,id='a"b\\c',function=FN()))
add('lone_surr',b'{"choices":[{"delta":{"content":"\\ud800"}}]}'); add('lone_low',b'{"choices":[{"delta":{"content":"\\udc00x"}}]}')
add('badhex',b'{"choices":[{"delta":{"content":"\\uZZZZ"}}]}'); add('bad_esc',b'{"choices":[{"delta":{"content":"\\q"}}]}')
add('invalid_utf8',b'{"choices":[{"delta":{"content":"\xff\xfe\x80\xc0\xaf"}}]}')
add('raw_ctl',b'{"choices":[{"delta":{"content":"a\x01\x1b[2Jb\nc"}}]}')
add('c1_split',D(content="\u00e2"),b'{"choices":[{"delta":{"content":"\x80"}}]}',b'{"choices":[{"delta":{"content":"\x94"}}]}')
for k,v in [('neg',-5),('huge',2**70),('f',1.5),('f2',1e300),('str','9'),('null',None),('obj',{}),('m1',-1)]:
    add('usage_'+k,J({"choices":[],"usage":{"total_tokens":v,"prompt_tokens":v,"completion_tokens":v}}),D(content="hi"))
add('usage_int',J({"choices":[],"usage":5})); add('usage_many',*[J({"choices":[],"usage":{"total_tokens":2**40,"prompt_tokens":2**40,"completion_tokens":2**40}})]*50,D(content="hi"))
add('fin_int',J({"choices":[{"delta":{"content":"x"},"finish_reason":5}]})); add('fin_obj',J({"choices":[{"delta":{"content":"x"},"finish_reason":{}}]}))
add('fin_len',J({"choices":[{"delta":{},"finish_reason":"length"}]})); add('fin_filter',J({"choices":[{"delta":{},"finish_reason":"content_filter"}]}))
add('err_str',J({"error":"boom"})); add('err_null',J({"error":None,"choices":[{"delta":{"content":"x"}}]})); add('err_int',J({"error":5}))
add('err_msg_int',J({"error":{"code":"x","message":5}})); add('err_code_huge',J({"error":{"code":2**70,"message":"m"}})); add('err_code_neg',J({"error":{"code":-5,"message":"m"}}))
add('err_msg_huge',J({"error":{"code":429,"message":"M"*300000}})); add('err_msg_esc',J({"error":{"code":429,"message":"\u001b[2J\u009b31m\nthoth: forged"}}))
add('depth_127',b'['*127+b']'*127); add('depth_129',b'['*129+b']'*129); add('depth_200k',b'['*200000)
add('depth_obj',b'{"a":'*150+b'1'+b'}'*150)
add('notjson',b'hello'); add('empty',b''); add('ws',b'   '); add('longnum',b'{"choices":[{"delta":{"content":"x"}}],"z":'+b'9'*100000+b'}')
add('longfloat',b'{"z":0.'+b'1'*100000+b'e99999999999999999}'); add('exp',b'{"z":1e-99999999999999999999}')
S['nodone']=sse([D(content="partial")],b'')
S['multi_data']=b'data: {"choices":[{"delta":\ndata: {"content":"x"}}]}\n\ndata: [DONE]\n\n'
S['crlf']=b'data: '+D(content="crlf")+b'\r\n\r\ndata: [DONE]\r\n\r\n'
S['cr_only']=b'data: '+D(content="cr")+b'\r\rdata: [DONE]\r\r'
S['comments']=b': hi\n\nevent: x\nid: 5\nretry: 1\ndata: '+D(content="c")+b'\n\ndata:[DONE]\n\n'
S['noeol']=b'data: '+D(content="x")
S['big_line_nonl']=b'data: '+b'A'*2000000
S['big_frame_ok']=b'data: '+D(content="B"*300000)+b'\n\ndata: [DONE]\n\n'
S['many_small']=sse([D(content="x")]*20000)
S['nul_in_frame']=b'data: {"choices":\x00[{"delta":{"content":"x"}}]}\n\ndata: [DONE]\n\n'
S['binary']=bytes(range(256))*200
def wrap(b,ct=b'text/event-stream'): return b'HTTP/1.1 200 OK\r\nContent-Type: '+ct+b'\r\nContent-Length: %d\r\nConnection: close\r\n\r\n'%len(b)+b
RAW={}
b=sse([D(content="hi")])
RAW['cl_neg']=b'HTTP/1.1 200 OK\r\nContent-Length: -5\r\nContent-Type: text/event-stream\r\nConnection: close\r\n\r\n'+b
RAW['cl_huge']=b'HTTP/1.1 200 OK\r\nContent-Length: 99999999999999999999\r\nContent-Type: text/event-stream\r\nConnection: close\r\n\r\n'+b
RAW['cl_big']=b'HTTP/1.1 200 OK\r\nContent-Length: 9223372036854775807\r\nContent-Type: text/event-stream\r\nConnection: close\r\n\r\n'+b
RAW['cl_double']=b'HTTP/1.1 200 OK\r\nContent-Length: 5\r\nContent-Length: 500\r\nContent-Type: text/event-stream\r\nConnection: close\r\n\r\n'+b
RAW['chunk_neg']=b'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/event-stream\r\n\r\n-5\r\nabc\r\n0\r\n\r\n'
RAW['chunk_huge']=b'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/event-stream\r\n\r\nffffffffffffffff\r\nabc\r\n0\r\n\r\n'
RAW['chunk_huge2']=b'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/event-stream\r\n\r\n7fffffffffffffff\r\nabc\r\n0\r\n\r\n'
RAW['chunk_huge3']=b'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/event-stream\r\n\r\n10000000000000000\r\nabc\r\n0\r\n\r\n'
RAW['chunk_noterm']=b'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/event-stream\r\n\r\n5'
RAW['chunk_ext']=b'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/event-stream\r\n\r\n%x;a=b\r\n'%len(b)+b+b'\r\n0\r\n\r\n'
RAW['chunk_trailer']=b'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n%x\r\n'%len(b)+b+b'\r\n0\r\nX: y\r\nSet-Cookie: a\r\n\r\n'
RAW['chunk_bad_hex']=b'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nzz\r\nabc\r\n0\r\n\r\n'
RAW['status_trunc']=b'HTTP/1.1'; RAW['status_junk']=b'GARBAGE\r\n\r\n'; RAW['status_999']=b'HTTP/9.9 999 X\r\nConnection: close\r\n\r\n'; RAW['status_neg']=b'HTTP/1.1 -200 X\r\n\r\n'
RAW['status_huge']=b'HTTP/1.1 99999999999999999999 X\r\n\r\n'; RAW['status_301']=b'HTTP/1.1 301 M\r\nLocation: http://127.0.0.1:1/x\r\nContent-Length: 0\r\n\r\n'
RAW['status_100s']=b'HTTP/1.1 100 Continue\r\n\r\n'*2000+b'HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n'
RAW['hdr_huge']=b'HTTP/1.1 200 OK\r\nX: '+b'a'*2000000+b'\r\n\r\n'; RAW['hdr_many']=b'HTTP/1.1 200 OK\r\n'+b'X: y\r\n'*200000+b'\r\n'
RAW['hdr_nocolon']=b'HTTP/1.1 200 OK\r\nnocolon\r\n:\r\n: v\r\n\r\n'; RAW['hdr_trunc']=b'HTTP/1.1 200 OK\r\nX: y'
RAW['empty']=b''; RAW['err500']=b'HTTP/1.1 500 X\r\nContent-Type: application/json\r\nContent-Length: 0\r\n\r\n'
RAW['gzip']=b'HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: 4\r\n\r\nabcd'
def blockwrap(b): return wrap(b,b'application/json')
B={}
def badd(n,o): B[n]=o if isinstance(o,bytes) else J(o)
M=lambda **k: {"choices":[{"message":dict({"role":"assistant"},**k),"finish_reason":"stop"}]}
BTC=lambda *t: M(content=None,tool_calls=list(t))
c=lambda i,n='read_file',a='{"path":"a.txt"}': {"id":i,"type":"function","function":{"name":n,"arguments":a}}
badd('b_choices_int',{"choices":5}); badd('b_msg_int',{"choices":[{"message":5}]}); badd('b_content_int',M(content=5)); badd('b_content_null',M(content=None))
badd('b_tc_str',M(tool_calls="x")); badd('b_tc_int_el',M(tool_calls=[5])); badd('b_tc_null_el',M(tool_calls=[None,{}]));
badd('b_tc_fn_int',M(tool_calls=[{"id":"a","function":5}])); badd('b_tc_noid',BTC({"type":"function","function":{"name":"read_file","arguments":"{}"}}))
badd('b_tc_noname',BTC({"id":"a","function":{"arguments":"{}"}})); badd('b_tc_emptyname',BTC({"id":"a","function":{"name":"","arguments":"{}"}}))
badd('b_tc_many',BTC(*[c('c%d'%i) for i in range(40)])); badd('b_tc_huge_id',BTC(c('Z'*500000)))
badd('b_tc_huge_args',BTC(c('a',a='{"path":"'+'p'*300000+'"}')))
badd('b_tc_obj_args',BTC({"id":"a","function":{"name":"read_file","arguments":{"path":"a.txt"}}}))
badd('b_tc_deep_args',b'{"choices":[{"message":{"tool_calls":[{"id":"a","function":{"name":"read_file","arguments":'+b'['*120+b']'*120+b'}}]}}]}')
badd('b_usage_huge',dict(M(content="x"),usage={"total_tokens":2**70,"prompt_tokens":2**62,"completion_tokens":2**62}))
badd('b_big',M(content="x"*5000000)); badd('b_notjson',b'<html>'); badd('b_empty',b''); badd('b_trailing',b'{"choices":[]} x'); badd('b_dup',b'{"choices":[],"choices":[]}')
badd('b_depth',b'['*100000)
cur=None; mode='stream'; reqs=[]; tool_dump=bool(os.environ.get('THOTH_HOSTILE_PAIRS')); cur_name=''
def srv():
    s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); s.bind(('127.0.0.1',PORT)); s.listen(32)
    while True:
        c,_=s.accept(); threading.Thread(target=one,args=(c,),daemon=True).start()
def one(c):
    try:
        c.settimeout(5)
        data=b''
        while b'\r\n\r\n' not in data:
            d=c.recv(1<<20)
            if not d: return
            data+=d
        head,body=data.split(b'\r\n\r\n',1)
        m=re.search(rb'content-length: *(\d+)',head,re.I); cl=int(m.group(1)) if m else 0
        while len(body)<cl:
            d=c.recv(1<<20)
            if not d: break
            body+=d
        if head.startswith(b'GET'):
            c.sendall(b'HTTP/1.1 404 N\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'); return
        ok=True
        try: j=json.loads(body)
        except Exception: ok=False; j={}
        reqs.append((ok,len(body),body if not ok else None))
        if tool_dump and ok and any(m.get('role')=='tool' for m in j.get('messages',[])):
            ms=j['messages']; ids=[]; res=[]
            for m in ms:
                if m.get('tool_calls'): ids+= [t.get('id') for t in m['tool_calls']]
                if m.get('role')=='tool': res.append(m.get('tool_call_id'))
            print('PAIR',cur_name,'echo',len(ids),[(i or '')[:24] for i in ids][:6],'results',len(res),[(r or '')[:24] for r in res][:6],'lens',[len(i or '') for i in ids][:3],[len(r or '') for r in res][:3],flush=True)
        tool=any(m.get('role')=='tool' for m in j.get('messages',[]))
        if tool:
            r=(wrap(sse([D(content="final")])) if mode=='stream' else blockwrap(J(M(content="final"))))
        elif mode=='raw': r=cur
        elif mode=='stream': r=wrap(cur)
        else: r=blockwrap(cur)
        c.sendall(r)
    except Exception: pass
    finally:
        try: c.shutdown(socket.SHUT_RDWR)
        except: pass
        c.close()
threading.Thread(target=srv,daemon=True).start(); time.sleep(0.3)
bad=[]; res=[]
def run(name,m,payload,stream):
    global cur,mode,reqs,cur_name
    cur_name=name
    cur=payload; mode=m; reqs=[]
    cfg(stream)
    env=dict(os.environ,HOME=H)
    t0=time.time()
    try:
        p=subprocess.run([BIN,'-p','read a.txt please'],cwd=P,env=env,stdin=subprocess.DEVNULL,capture_output=True,timeout=25)
        rc=p.returncode; out=p.stdout[:120]; err=p.stderr[:160]
    except subprocess.TimeoutExpired:
        rc='HANG'; out=b''; err=b''
    dt=time.time()-t0
    inval=[r for r in reqs if not r[0]]
    flag=''
    if rc=='HANG' or (isinstance(rc,int) and rc<0): flag='CRASH'
    if inval: flag+=' BADREQ'
    res.append((name,rc,round(dt,1),len(reqs),flag))
    if flag: print('!!',name,rc,flag,out,err,[ (r[1],(r[2] or b'')[-80:]) for r in inval][:2],flush=True)
only=sys.argv[2] if len(sys.argv)>2 else ''
for n,p in S.items():
    if only in n: run(n,'stream',p,True)
for n,p in RAW.items():
    if only in n: run('raw_'+n,'raw',p,True)
for n,p in B.items():
    if only in n: run(n,'block',p,False)
print(len(res),'scenarios')
for r in res:
    print(r)
sys.exit(1 if any(r[4] for r in res) else 0)
