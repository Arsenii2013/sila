
import os
import re

import SCons.Builder
import SCons.Scanner

from utils import *
from functools import reduce

def systemVerilog(target, source, env):

    trg      = target[0]
    trg_path = str(trg)
    trg_dir  = str(trg.dir)

    src_path = list(map(str, source))

    print_action('generate StstemVerilog axi cores from' + reduce(lambda acc, x: acc + f' {x}', src_path, ''))

    for s in src_path:
        cmd = f"{env['PEAKRDL']} regblock {env['REGBOCK_FLAGS']} {s} -o {trg_dir} "
        rcode = pexec(cmd, env['USER_DEFINED_PARAMS']['ROOT_DIR'], exec_env=env['ENV'])
        if rcode:
            print_error('\n' + '*'*60)
            print_error('E: axi_core generation error')
            print_error('*'*60 + '\n')
            Execute( Delete(trg_path) )
            return -2
    
    print_success('\n' + '*'*35)
    print_success('axi_cores successfully generated')
    print_success('*'*35 + '\n')
    return None

def ymlList(target, source, env):

    trg      = target[0]
    trg_path = str(trg)
    trg_dir  = str(trg.dir)

    src_path = list(map(str, source))

    print_action('generate axi cores YML list from' + reduce(lambda acc, x: acc + f' {x}', src_path, ''))

    body = reduce(lambda acc, x: acc + f'    - {x}' + os.linesep, src_path, '')
    
    with open(str(os.path.basename(trg_path)), mode = 'a+') as f:
        if not f.read(1):
            print_info('write header')
            f.write("sources:"+ os.linesep)
        f.write(body)

    return None

def registerMapHTML(target, source, env):
    
    trg      = target[0]
    trg_path = str(trg)
    trg_dir  = str(trg.dir)

    src_path = list(map(str, source))

    print_action('generate register map for axi cores from' + reduce(lambda acc, x: acc + f' {x}', src_path, ''))

    for s in src_path:
        cmd = f"{env['PEAKRDL']} html {s} -o {trg_dir}/{os.path.splitext(os.path.basename(s))[0]}_html/  "
        rcode = pexec(cmd, env['USER_DEFINED_PARAMS']['ROOT_DIR'], exec_env=env['ENV'])
        if rcode:
            print_error('\n' + '*'*60)
            print_error('E: axi_core generation error')
            print_error('*'*60 + '\n')
            Execute( Delete(trg_path) )
            return -2
    
    print_success('\n' + '*'*35)
    print_success('axi_cores successfully generated')
    print_success('*'*35 + '\n')
    return None

def registerMapDocx(target, source, env):
    trg      = target[0]
    trg_path = str(trg)
    trg_dir  = str(trg.dir)

    src_path = list(map(str, source))

    print_action('generate register map for axi cores from' + reduce(lambda acc, x: acc + f' {x}', src_path, ''))

    for s in src_path:
        cmd = f"{env['PEAKRDL']} docx {s} -o {trg_dir}/{os.path.splitext(os.path.basename(s))[0]}.docx "
        rcode = pexec(cmd, env['USER_DEFINED_PARAMS']['ROOT_DIR'], exec_env=env['ENV'])
        if rcode:
            print_error('\n' + '*'*60)
            print_error('E: axi_core generation error')
            print_error('*'*60 + '\n')
            Execute( Delete(trg_path) )
            return -2
    
    print_success('\n' + '*'*35)
    print_success('axi_cores successfully generated')
    print_success('*'*35 + '\n')
    return None

def pythonPackage(target, source, env):
    
    trg      = target[0]
    trg_path = str(trg)
    trg_dir  = str(trg.dir)

    src_path = list(map(str, source))

    print_action('generate python package for axi cores from' + reduce(lambda acc, x: acc + f' {x}', src_path, ''))

    for s in src_path:
        cmd = f"{env['PEAKRDL']} python {s} -o {trg_dir}/{os.path.splitext(os.path.basename(s))[0]}_py/  "
        rcode = pexec(cmd, env['USER_DEFINED_PARAMS']['ROOT_DIR'], exec_env=env['ENV'])
        if rcode:
            print_error('\n' + '*'*60)
            print_error('E: axi_core generation error')
            print_error('*'*60 + '\n')
            Execute( Delete(trg_path) )
            return -2
    
    print_success('\n' + '*'*35)
    print_success('axi_cores successfully generated')
    print_success('*'*35 + '\n')
    return None

def generate_axi_cores_system_verilog(env, src = [], trg = []):
    return env.AxiCoresSystemVerilog(trg, src, env)

def generate_axi_cores_yml(env, src = [], trg = []):
    return env.AxiCoresYML(trg, src, env)

def generate_register_map_html(env, src = [], trg = []):
    return env.RegisterMapHTML(trg, src, env)

def generate_register_map_docx(env, src = [], trg = []):
    return env.RegisterMapDocx(trg, src, env)

def generate_python_package(env, src = [], trg = []):
    return env.AxiCoresPythonPackage(trg, src, env)


def generate(env):
    
    Scanner = SCons.Scanner.Scanner
    Builder = SCons.Builder.Builder
    
    #-----------------------------------------------------------------
    #
    #    External Environment
    #
    if not 'PEAKRDL' in env:
        print_error('E: PEAKRDL must be defined in construction environmet')
        Exit(-1)
        
    #-----------------------------------------------------------------
    #
    #    Construction Variables
    #
    if not 'BUILD_VARIANT' in env:
        print_error('E: "BUILD_VARIANT" construction environment variable must be defined and specifed build variant relative to "cfg" path')
        Exit(-2)

    build_variant         = env['BUILD_VARIANT']
    root_dir              = str(env.Dir('#'))

    #-----------------------------------------------------------------
    #
    #   Builders
    #
    AxiCoresSystemVerilog = Builder(action = systemVerilog)
    AxiCoresYML           = Builder(action = ymlList)
    RegisterMapHTML       = Builder(action = registerMapHTML, target_factory=env.fs.Dir)
    RegisterMapDocx       = Builder(action = registerMapDocx)
    AxiCoresPythonPackage = Builder(action = pythonPackage, target_factory=env.fs.Dir)
    
    Builders = {
        'AxiCoresSystemVerilog'    : AxiCoresSystemVerilog,
        'AxiCoresYML'              : AxiCoresYML,
        'RegisterMapHTML'          : RegisterMapHTML,
        'RegisterMapDocx'          : RegisterMapDocx,
        'AxiCoresPythonPackage'    : AxiCoresPythonPackage
    }
    
    env.Append(BUILDERS = Builders)

    #-----------------------------------------------------------------
    #
    #   IP core processing pseudo-builders
    #
    env.AddMethod(generate_axi_cores_system_verilog,  'GenerateAxiCoresSystemVerilog')
    env.AddMethod(generate_axi_cores_yml,             'GenerateAxiCoresYML')
    env.AddMethod(generate_register_map_html,         'GenerateRegisterMapHTML')
    env.AddMethod(generate_register_map_docx,         'GenerateRegisterMapDocx')
    env.AddMethod(generate_python_package,            'GenerateAxiCoresPythonPackage')
        
#-------------------------------------------------------------------------------
def exists(env):
    print('peakrdl tool: exists')
#-------------------------------------------------------------------------------
    
