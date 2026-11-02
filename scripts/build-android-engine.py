#!/usr/bin/env python3
"""Build the same embedded Rust core for Android through the official NDK linker."""
import argparse,os,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--abi',choices=['arm64-v8a','x86_64'],required=True);p.add_argument('--ndk',type=Path,required=True);args=p.parse_args()
triple,linker=('aarch64-linux-android','aarch64-linux-android28-clang') if args.abi=='arm64-v8a' else ('x86_64-linux-android','x86_64-linux-android28-clang')
prebuilt=list((args.ndk/'toolchains/llvm/prebuilt').glob('*/bin'))
if len(prebuilt)!=1 or not (prebuilt[0]/linker).exists():raise SystemExit('Android NDK toolchain not found')
env=os.environ.copy();env['PATH']=str(Path.home()/'.cargo/bin')+os.pathsep+env.get('PATH','');env['CARGO_TARGET_'+triple.upper().replace('-','_')+'_LINKER']=str(prebuilt[0]/linker)
subprocess.run(['python3',str(ROOT/'scripts/engine-data.py'),'check'],check=True)
subprocess.run(['rustup','target','add',triple],cwd=ROOT/'engine',env=env,check=True)
subprocess.run(['cargo','build','--locked','--release','--target',triple],cwd=ROOT/'engine',env=env,check=True)
out=ROOT/'platforms/android/app/build/generated/shared-jni'/args.abi;out.mkdir(parents=True,exist_ok=True)
shutil.copyfile(ROOT/'engine/target'/triple/'release/libneptype_engine.so',out/'libNepTypeEngine.so')
print('Staged Rust engine and embedded dictionary:',out)
