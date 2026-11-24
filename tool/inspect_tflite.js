// Minimal TFLite flatbuffer reader: prints graph inputs/outputs, the op that
// produces each output, op counts, and metadata names. Usage: node inspect_tflite.js <model.tflite>
const fs = require('fs');
const buf = fs.readFileSync(process.argv[2]);
const u8 = (o) => buf.readUInt8(o);
const u16 = (o) => buf.readUInt16LE(o);
const u32 = (o) => buf.readUInt32LE(o);
const i32 = (o) => buf.readInt32LE(o);

function table(pos) {
  const vt = pos - i32(pos);
  const vtSize = u16(vt);
  const field = (i) => {
    const off = 4 + i * 2;
    if (off >= vtSize) return 0;
    const f = u16(vt + off);
    return f ? pos + f : 0;
  };
  return {
    pos,
    field,
    scalar(i, reader, def) { const p = field(i); return p ? reader(p) : def; },
    ref(i) { const p = field(i); return p ? p + u32(p) : 0; },
    vec(i) { const p = this.ref(i); return p ? { len: u32(p), start: p + 4 } : { len: 0, start: 0 }; },
    str(i) { const v = this.vec(i); return v.len ? buf.toString('utf8', v.start, v.start + v.len) : ''; },
    tables(i) { const v = this.vec(i); const out = []; for (let k = 0; k < v.len; k++) { const e = v.start + 4 * k; out.push(table(e + u32(e))); } return out; },
    ints(i) { const v = this.vec(i); const out = []; for (let k = 0; k < v.len; k++) out.push(i32(v.start + 4 * k)); return out; },
    floats(i) { const v = this.vec(i); const out = []; for (let k = 0; k < v.len; k++) out.push(buf.readFloatLE(v.start + 4 * k)); return out; },
    longs(i) { const v = this.vec(i); const out = []; for (let k = 0; k < v.len; k++) out.push(Number(buf.readBigInt64LE(v.start + 8 * k))); return out; },
  };
}

const TYPES = ['FLOAT32','FLOAT16','INT32','UINT8','INT64','STRING','BOOL','INT16','COMPLEX64','INT8','FLOAT64','COMPLEX128','UINT64','RESOURCE','VARIANT','UINT32','UINT16','INT4'];
const OPS = { 0:'ADD',1:'AVERAGE_POOL_2D',2:'CONCATENATION',3:'CONV_2D',4:'DEPTHWISE_CONV_2D',6:'DEQUANTIZE',9:'FULLY_CONNECTED',14:'LOGISTIC',17:'MAX_POOL_2D',18:'MUL',19:'RELU',21:'RELU6',22:'RESHAPE',25:'SOFTMAX',34:'PAD',40:'MEAN',114:'QUANTIZE' };

console.log('file identifier:', buf.toString('ascii', 4, 8), ' size:', buf.length);
const model = table(u32(0));
console.log('schema version:', model.scalar(0, u32, 0), ' description:', JSON.stringify(model.str(3)));

const opcodes = model.tables(1).map((oc) => {
  const dep = oc.scalar(0, (p) => buf.readInt8(p), 0);
  const bc = oc.scalar(3, i32, 0);
  const code = Math.max(dep, bc);
  return OPS[code] || `builtin_${code}`;
});

const sgs = model.tables(2);
console.log('subgraphs:', sgs.length);
const sg = sgs[0];
const tensors = sg.tables(0);
const ops = sg.tables(3);

function describe(idx) {
  const t = tensors[idx];
  const q = t.ref(4) ? table(t.ref(4)) : null;
  let quant = 'none';
  if (q) {
    const scale = q.floats(2), zp = q.longs(3);
    if (scale.length) quant = `scale=${scale[0]} zero_point=${zp[0]}`;
  }
  return `#${idx} name="${t.str(3)}" shape=[${t.ints(0).join(', ')}] dtype=${TYPES[t.scalar(1, u8, 0)]} shape_signature=[${t.ints(7).join(', ')}] quant=${quant}`;
}

console.log('\nINPUTS:');
for (const i of sg.ints(1)) console.log('  ' + describe(i));
console.log('OUTPUTS:');
for (const o of sg.ints(2)) {
  console.log('  ' + describe(o));
  const producer = ops.find((op) => op.ints(2).includes(o));
  if (producer) console.log(`    produced by op: ${opcodes[producer.scalar(0, u32, 0)]}`);
}

const counts = {};
for (const op of ops) { const n = opcodes[op.scalar(0, u32, 0)]; counts[n] = (counts[n] || 0) + 1; }
console.log('\nop count:', ops.length, JSON.stringify(counts));
const lastOps = ops.slice(-4).map((op) => opcodes[op.scalar(0, u32, 0)]);
console.log('last ops:', lastOps.join(' -> '));

const meta = model.tables(6).map((m) => m.str(0));
console.log('metadata entries:', meta.length ? meta.join(', ') : '(none)');
const sigs = model.tables(7);
console.log('signature defs:', sigs.length);
