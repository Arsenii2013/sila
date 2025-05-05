#-------------------------------------------------------------------------------
#
#    Build Variant Base Construction Script
#
#    Author: Harry E. Zhurov
#
#-------------------------------------------------------------------------------

import os
import sys

from utils import *

class BuildBase:

    def __init__(self, env, **src_dict):

        self.envx = env
        
        src_keys = ['src_syn', 'src_sim', 'ip', 'bd', 'hls']
        for k in src_dict:
            if not k in src_keys:
                print_error('E: invalid source key \'' + k + '\' specified for build class constructor')
                print_error('   valid source keys: \'' + '\', \''.join(src_keys) + '\'')
                Exit(-1)
        
        self.src_dict   = src_dict
        self.vsim_args = str(env['ARGUMENTS'].get('vsim_args', ''))

        self.setup_search_paths()
        self.add_sources()
        self.setup_constr_env()

        self.add_hls_script_targets()
        self.add_hls_targets()
        self.add_ip_targets()
        self.add_bd_targets()
        self.add_hdl_params_targets()
        self.add_tcl_params_targets()
        self.add_main_targes()
        self.add_phony_targes()

        self.setup_explicit_dependensies()
        self.setup_default_targets()

        self.define_target_aliases()
        self.setup_target_help()

        self.setup_extensions()


    #---------------------------------------------------------------------------
    #
    #    Configuration
    #
    def setup_search_paths(self):

        add_search_path( os.path.join( os.getcwd(), 'env') )
        add_search_path( os.path.join( os.getcwd(), os.pardir, 'common', 'env') )

        dirs = import_config('dirpath.yml')
        self.dirs = dirs
        self.envx['EXT_SCRIPT_PATH'] = dirs.SCRIPT_COMMON

        # path
        add_search_path(dirs.COMMON)
        add_search_path(dirs.CFG_COMMON)
        add_search_path(os.path.join(dirs.ROOT))

        add_check_exclude_path(dirs.BUILD)                        # prevent file exist check for generated files

        sys.path.append(dirs.SCRIPT)
        sys.path.append(dirs.SCRIPT_COMMON)

    #---------------------------------------------------------------------------
    #
    #    Sources
    #
    def merge_source_list(self, src_cfg):
        import itertools
        
        return list( itertools.chain.from_iterable( [read_sources(i) for i in src_cfg.split()] ) )
    
    def add_sources(self):
        
        src_syn = '' + (self.src_dict['src_syn'] if 'src_syn' in self.src_dict else '')
        src_sim = '' + (self.src_dict['src_sim'] if 'src_sim' in self.src_dict else '')
        ip      = '' + (self.src_dict['ip']      if 'ip'      in self.src_dict else '')
        hls     = '' + (self.src_dict['hls']     if 'hls'     in self.src_dict else '')
        bd      = '' + (self.src_dict['bd']      if 'bd'      in self.src_dict else '')
        
        self.src_syn        = self.merge_source_list(src_syn)      # list( itertools.chain.from_iterable( [read_sources(i) for i in src_syn.split()] ) )
        self.src_sim        = self.merge_source_list(src_sim)      # read_sources('src_sim.yml')
        self.ip             = self.merge_source_list(ip)           # list( itertools.chain.from_iterable( [read_sources(i) for i in ip.split()] ) )
        self.hls            = self.merge_source_list(hls)          # read_sources('hls.yml')
        self.bd             = self.merge_source_list(bd)           # read_sources('bd.yml')

        self.xdc            = read_sources('xdc.yml')
        self.xpr_hook       = read_sources('xpr_hook.yml')

        self.syn_deps       = self.src_syn + self.xdc
        self.hdl_param_deps = 'main.yml clk.yml ila.yml'
        self.xpr_deps       = src_syn.split() + 'src_sim.yml xdc.yml'.split() + self.xpr_hook

        self.ila_settings   = os.path.join(self.dirs.CFG, 'script', 'ila.tcl')
        self.prj_impl_deps  = [self.ila_settings]

    #---------------------------------------------------------------------------
    #
    #    Construction Environment
    #
    def setup_constr_env(self):

        cfg = import_config('main.yml')
        env = import_config('env.yml')

        self.envx['ENV']['DISPLAY']            = os.environ['DISPLAY']
        self.envx['ENV']['HOME']               = os.environ['HOME']
        self.envx['ENV']['XILINX']             = env.XILINX
        self.envx['ENV']['MENTOR']             = env.MENTOR
        self.envx['ENV']['MGLS_LICENSE_FILE']  = env.MGLS_LICENSE_FILE
        self.envx['ENV']['XILINX_VIVADO']      = env.XILINX_VIVADO
        self.envx['XILINX_VIVADO']             = env.XILINX_VIVADO
        self.envx['XILINX_HLS']                = env.XILINX_HLS
        self.envx['QUESTABIN']                 = env.QUESTABIN
        self.envx['QUESTASIM']                 = env.QUESTASIM
        self.envx['VENDOR_LIB_PATH']           = env.VENDOR_LIB_PATH

        self.envx.Tool('vivado')
        self.envx.Tool('questa')

        self.envx['VIVADO_PROJECT_NAME']  = cfg.PROJECT_NAME
        self.envx['TOP_NAME']             = cfg.TOP_NAME
        self.envx['TESTBENCH_NAME']       = cfg.TESTBENCH_NAME
        self.envx['DEVICE']               = cfg.DEVICE

        self.envx.Append( CONFIG_SEARCH_PATH = get_search_path() )  # search path list for settings files (typically *.yml)
        self.envx.Append( INC_PATH = [self.envx['BUILD_SRC_PATH'], self.dirs.LIB] + get_dirs(self.src_syn) )
        self.envx.Append( SIM_INC_PATH = self.envx['INC_PATH'])

        # Tool flags
        vlog_flags  = ' -O5 -timescale=1ns/1ps -ccflags -I' + os.path.join(env.XILINX_HLS, 'include') + ' -ccflags "-std=c++14" -ccflags "-Wall" -ccflags "-Wpedantic"' + ' +incdir'
        vsim_flags  = ' ' + self.vsim_args

        self.envx.Append(VLOG_FLAGS = vlog_flags)
        self.envx.Append(VOPT_FLAGS = ' -O5 +acc=npr -L wlib -L unifast_ver -L unisims_ver -L unimacro_ver -L secureip -L xpm')
        self.envx.Append(VSIM_FLAGS = vsim_flags)

        # user-defined parameters
        self.envx.Append(USER_DEFINED_PARAMS = {'ROOT_DIR'      : self.envx['ROOT_PATH']})
        self.envx.Append(USER_DEFINED_PARAMS = {'CFG_DIR'       : self.envx['CFG_PATH']})
        self.envx.Append(USER_DEFINED_PARAMS = {'BUILD_SRC_DIR' : self.envx['BUILD_SRC_PATH']})
        self.envx.Append(USER_DEFINED_PARAMS = {'SRC_SIM'       : self.dirs.SRC_SIM})
        self.envx.Append(USER_DEFINED_PARAMS = {'VARIANT_NAME'  : cfg.VARIANT_NAME})

        self.envx['PROJECT_CREATE_FLAGS'] = '-f'

    #---------------------------------------------------------------------------
    #
    #    Targets
    #
    def add_hls_script_targets(self):
        self.HlsCSynScripts = self.envx.CreateHlsCSynthScript(self.hls)

    #---------------------------------------------------------------------------
    def add_hls_targets(self):
        self.HlsCsyn = self.envx.LaunchHlsCSynth(self.HlsCSynScripts, self.hls)

    #---------------------------------------------------------------------------
    def add_ip_targets(self):
        #   IP scripts
        self.IP_Create_Scripts  = self.envx.IpCreateScripts(self.ip)
        self.IP_Syn_Scripts     = self.envx.IpSynScripts(self.ip)
        self.HLS_IP_Syn_Scripts = self.envx.HlsIpSynScripts(self.HlsCsyn)

        #   IP cores
        self.IP_Cores           = self.envx.CreateIps(self.IP_Create_Scripts)
        self.All_IP             = self.IP_Cores + self.HlsCsyn

        self.All_IP_Syn_Scripts = self.IP_Syn_Scripts + self.HLS_IP_Syn_Scripts
        self.IP_OOC_Syn         = self.envx.SynIps(self.All_IP_Syn_Scripts, self.All_IP)

    #---------------------------------------------------------------------------
    def add_bd_targets(self):
        self.bd_ooc = self.envx.CreateOocBd(self.bd)

    #---------------------------------------------------------------------------
    def add_hdl_params_targets(self):
        cfg_params_header   = os.path.join(self.envx['BUILD_SRC_PATH'], 'cfg_params.svh')

        self.CfgParamsHeader    = self.envx.CreateCfgParamsHeader(cfg_params_header, self.hdl_param_deps)

        self.cfg_header_trgs    = [self.CfgParamsHeader]

    #---------------------------------------------------------------------------
    def add_tcl_params_targets(self):

        cfg_params_tcl      = os.path.join(self.envx['BUILD_SRC_PATH'], 'cfg_params.tcl')
        env_params_tcl      = os.path.join(self.envx['BUILD_SRC_PATH'], 'env_params.tcl')
        ila_params_tcl      = os.path.join(self.envx['BUILD_SRC_PATH'], 'ila_params.tcl')
        impl_env_tcl        = os.path.join(self.envx['BUILD_SRC_PATH'], 'impl_env.tcl')

        self.prj_impl_deps.append(impl_env_tcl)

        self.CfgParamsTcl   = self.envx.CreateCfgParamsTcl(cfg_params_tcl, 'main.yml clk.yml')
        self.EnvParamsTcl   = self.envx.CreateCfgParamsTcl(env_params_tcl, 'env.yml dirpath.yml')
        self.IlaParamsTcl   = self.envx.CreateCfgParamsTcl(ila_params_tcl, 'ila.yml')
        self.ImplEnvTcl     = self.envx.CreateCfgParamsTcl(impl_env_tcl,   'main.yml clk.yml dirpath.yml ila.yml')

        self.cfg_tcl_trgs   = [self.CfgParamsTcl,
                               self.EnvParamsTcl,
                               self.IlaParamsTcl,
                               self.ImplEnvTcl]


    #---------------------------------------------------------------------------
    def add_main_targes(self):
        self.WLib               = self.envx.CompileWorkLib(self.src_syn + self.src_sim + self.envx['BD_WRAPPERS'])
        self.VivadoProject      = self.envx.CreateVivadoProject(self.xpr_deps, self.All_IP, self.bd_ooc)
        self.SynthVivadoProject = self.envx.LaunchSynthVivadoProject(self.VivadoProject, self.syn_deps)
        self.ImplVivadoProject  = self.envx.LaunchImplVivadoProject(self.SynthVivadoProject)

        #   sim libs
        self.IP_SimLib          = self.envx.CompileSimLib(self.All_IP + self.bd_ooc)

    def add_phony_targes(self):
        self.LaunchQuestaGui    = self.envx.LaunchQuestaGui()
        self.LaunchQuestaRun    = self.envx.LaunchQuestaRun()
        self.OpenVivadoProject  = self.envx.LaunchOpenVivadoProject(self.VivadoProject)


    def setup_explicit_dependensies(self):
        Depends(self.WLib,               [self.IP_SimLib, self.bd_ooc, self.cfg_header_trgs])
        Depends(self.LaunchQuestaRun,    self.WLib)
        Depends(self.VivadoProject,      [self.cfg_header_trgs, self.cfg_tcl_trgs])
        Depends(self.bd_ooc,             [self.cfg_tcl_trgs])
        Depends(self.SynthVivadoProject, [self.cfg_header_trgs])
        Depends(self.ImplVivadoProject,  self.prj_impl_deps)
        Depends(self.OpenVivadoProject,  [self.IP_OOC_Syn, self.cfg_header_trgs])


    def setup_default_targets(self):
        if not 'prj' in COMMAND_LINE_TARGETS:
            Requires(self.VivadoProject, self.IP_OOC_Syn)

        self.envx.AlwaysBuild(self.WLib)
        self.envx.AlwaysBuild(self.LaunchQuestaGui)

        Default(self.WLib)
        self.all = [self.WLib, self.ImplVivadoProject]

    #---------------------------------------------------------------------------
    #
    #    Target Aliases
    #
    def define_target_aliases(self):
        self.envx.Alias('ipcs',       self.IP_Create_Scripts)
        self.envx.Alias('ipss',       self.IP_Syn_Scripts + self.HLS_IP_Syn_Scripts)
        self.envx.Alias('ip_cores',   self.IP_Cores)
        self.envx.Alias('ip_ooc',     self.IP_OOC_Syn)

        self.envx.Alias('bd_ooc',     self.bd_ooc)

        self.envx.Alias('hlss',       self.HlsCSynScripts)
        self.envx.Alias('hls',        self.HlsCsyn)

        self.envx.Alias('simlib',     self.IP_SimLib)
        self.envx.Alias('hdl-params', self.cfg_header_trgs)
        self.envx.Alias('tcl-params', self.cfg_tcl_trgs)
        self.envx.Alias('wlib',       self.WLib)
        self.envx.Alias('qs_gui',     self.LaunchQuestaGui)
        self.envx.Alias('qs_run',     self.LaunchQuestaRun)

        self.envx.Alias('prj',        self.VivadoProject)
        self.envx.Alias('prjsyn',     self.SynthVivadoProject)
        self.envx.Alias('prjimpl',    self.ImplVivadoProject)
        self.envx.Alias('prjopen',    self.OpenVivadoProject)

        self.envx.Alias('all',        self.all)

    #---------------------------------------------------------------------------
    #
    #    Info
    #
    def setup_target_help(self):
        Help("""
            Variant '%s' available targets:
            ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                ipcs       : IP Create Scripts
                ipss       : IP Synthesize Scripts
                ip_cores   : Create IPs
                ip_ooc     : Create IP design checkpoints by sythisizing of 'xci's

                bd_ooc     : Create block designs in out-of-context manner

                simlib     : IP SimLib

                hlss       : create Tcl scripts for compiling HDL modules from HLS sources
                hls        : create HDL modules from HLS sources

                hdl-params : generate HDL parameter headers
                tcl-params : generate Tcl parameters scripts

                wlib       : compile work library (default)
                qs_gui     : launch Questa GUI in destination dir with tool script loaded
                qs_run     : launch simulation run in non-GUI mode

                prj        : create Vivado Project
                prjsyn     : synthesize Vivado Project
                prjimpl    : implement Vivado Project
                prjopen    : open Vivado Project in GUI mode

                all        : build wlib and prjimpl targets

            Optional arguments:
            ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                no_colors=<0|1>       : on/off messages colorization

        ********************************************************************************
        """ % os.getcwd().split(os.sep)[-1])

    def setup_extensions(self):

        if 'VIVADO_LOG_MONITOR_ENABLE' in os.environ:
            self.envx.AddPreAction(self.SynthVivadoProject, show_syn_log)
            self.envx.AddPreAction(self.ImplVivadoProject, show_impl_log)

        self.Rpt = self.envx.Command(['reports'], [], show_reports)

        self.envx.Alias('rpt', self.Rpt)
        self.envx.AddPostAction(self.SynthVivadoProject, warning_summary)
        self.envx.AddPostAction(self.ImplVivadoProject,  show_reports)

        Help("""
            Report control
            ~~~~~~~~~~~~~~

            scons -s rpt            : display utilization, timing and warning summary info
            scosn -s rpt warn=<arg> : can be 'syn', 'impl', 'all'.
                                      Display corresponding warnings
        """)

#-------------------------------------------------------------------------------
#
#  Extensions
#

#---------------------------------------------------------------------
#    Logs

#-------------------------------------------------
def show_syn_log(target, source, env):
    log    = os.path.join(env['BUILD_SYN_PATH'], env['VIVADO_PROJECT_NAME'] + '.runs', 'synth_1', 'runme.log')
    logmon = os.path.join(env['EXT_SCRIPT_PATH'], 'syn_lmon.sh')

    cmd = 'gnome-terminal -t Vivado Synthesis  -- zsh -c "' + logmon + ' ' + log + '"'
    os.system(cmd)
#-------------------------------------------------
def show_impl_log(target, source, env):
    log    = os.path.join(env['BUILD_SYN_PATH'], env['VIVADO_PROJECT_NAME'] + '.runs', 'impl_1', 'runme.log')
    logmon = os.path.join(env['EXT_SCRIPT_PATH'], 'impl_lmon.sh')

    cmd = 'gnome-terminal -t Vivado Implementation  -- zsh -c "' + logmon + ' ' + log + '"'
    os.system(cmd)
#-------------------------------------------------


#---------------------------------------------------------------------
#    Reports
from tabulate import tabulate

def warning_summary(target, source, env):
    sys.path.append(env['EXT_SCRIPT_PATH'])

    import vivado_report as vrpt

    vrpt.warning_report(env, 'syn')

def show_reports(target, source, env):
    sys.path.append(env['EXT_SCRIPT_PATH'])

    import tabulate
    from   tabulate import tabulate as tab
    import vivado_report as vrpt

    warn_opt_str = env['ARGUMENTS'].get('warn', '')
    warn_opt     = warn_opt_str.split()

    vrpt.utilization_report(env)
    vrpt.timing_report(env)
    vrpt.warning_report(env, warn_opt)

#-------------------------------------------------------------------------------
