"""Replace an existing test APK's assets while retaining its exact native runtime.

Produces an unsigned APK. Sign separately with the existing private certificate.
"""
import argparse, struct, zipfile
from pathlib import Path

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('original',type=Path);p.add_argument('pack',type=Path)
p.add_argument('output',type=Path);p.add_argument('--version-code',type=int,required=True)
p.add_argument('--old-name',required=True);p.add_argument('--new-name',required=True)
p.add_argument('--app-label', default=None)
args=p.parse_args()

def manifest(data):
    raw=bytearray(data)
    strings=[];offset=8;found=False;pool_offset=0;pool_size=0;pool_header=0
    while offset<len(raw):
        kind,header,size=struct.unpack_from('<HHI',raw,offset)
        if kind==1:
            count,styles,flags,start,_=struct.unpack_from('<IIIII',raw,offset+8)
            pool_offset=offset;pool_size=size;pool_header=header
            if styles: raise ValueError('Styled manifest pool unsupported')
            if flags & 256: raise ValueError('Expected original UTF16 Android manifest')
            for i in range(count):
                index=offset+start+struct.unpack_from('<I',raw,offset+header+i*4)[0]
                length=struct.unpack_from('<H',raw,index)[0]
                if length & 0x8000: raise ValueError('Unexpected extended manifest string')
                strings.append(raw[index+2:index+2+length*2].decode('utf-16le'))
        elif kind==0x102:
            attr_start,attr_size,attr_count=struct.unpack_from('<HHH',raw,offset+24)
            for i in range(attr_count):
                attr=offset+16+attr_start+i*attr_size
                name=struct.unpack_from('<I',raw,attr+4)[0]
                if args.app_label and strings[name]=='label':
                    struct.pack_into('<I',raw,attr+8,len(strings))
                    struct.pack_into('<HBBI',raw,attr+12,8,0,3,len(strings))
                if strings[name]=='versionCode':
                    struct.pack_into('<I',raw,attr+16,args.version_code);found=True
        if size<8: raise ValueError('Malformed chunk')
        offset+=size
    if not found: raise ValueError('versionCode missing')
    old=args.old_name.encode('utf-16le');new=args.new_name.encode('utf-16le')
    if len(old)!=len(new) or raw.count(old)!=1: raise ValueError('Version-name replacement must be equal length and unique')
    raw=bytearray(bytes(raw).replace(old,new))
    if args.app_label:
        strings=[args.new_name if s==args.old_name else s for s in strings]+[args.app_label]
        offsets=[];payload=bytearray()
        for s in strings:
            encoded=s.encode('utf-16le');offsets.append(len(payload))
            payload+=struct.pack('<H',len(encoded)//2)+encoded+b'\0\0'
        payload+=bytes((-len(payload))%4)
        start=pool_header+4*len(strings)
        chunk=bytearray(raw[pool_offset:pool_offset+pool_header])
        struct.pack_into('<I',chunk,4,start+len(payload))
        struct.pack_into('<IIIII',chunk,8,len(strings),0,0,start,0)
        chunk+=struct.pack('<'+'I'*len(offsets),*offsets)+payload
        raw[pool_offset:pool_offset+pool_size]=chunk
        struct.pack_into('<I',raw,4,len(raw))
    return bytes(raw)

with zipfile.ZipFile(args.original) as old, zipfile.ZipFile(args.pack) as pack, zipfile.ZipFile(args.output,'w') as out:
    previous={i.filename:i for i in old.infolist()}
    def write(name,data,compression):
        item=zipfile.ZipInfo(name);item.compress_type=compression
        # Match original stored-file alignment. Libraries stay in their original compression mode.
        if compression==zipfile.ZIP_STORED:
            pad=(-out.fp.tell()-30-len(name.encode())-4)%4
            item.extra=struct.pack('<HH',0xffff,pad)+bytes(pad)
        out.writestr(item,data)
    for item in old.infolist():
        if item.filename.startswith('META-INF/'):continue
        if item.filename.startswith('assets/') and item.filename!='assets/_cl_':continue
        data=old.read(item)
        if item.filename=='AndroidManifest.xml':data=manifest(data)
        write(item.filename,data,item.compress_type)
    for item in pack.infolist():
        if item.is_dir():continue
        name='assets/'+item.filename
        compression=previous[name].compress_type if name in previous else zipfile.ZIP_DEFLATED
        write(name,pack.read(item),compression)
print('Unsigned APK',args.output.stat().st_size,'bytes')
