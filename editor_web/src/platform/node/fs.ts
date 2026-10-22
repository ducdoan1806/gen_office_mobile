const denied = () => { throw Error('Filesystem is available only through the Android document bridge.'); };
export const closeSync = denied, fsyncSync = denied, openSync = denied, readFileSync = denied, writeFileSync = denied, writeSync = denied, createWriteStream = denied;
export const rename = denied, rm = denied, copyFile = denied, mkdir = denied, mkdtemp = denied, stat = denied, unlink = denied, pipeline = denied, tmpdir = denied;
