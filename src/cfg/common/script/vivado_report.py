#------------------------------------------------------------------------------
#
#       Project:        Any
#
#       Description:    Display summary reports
#
#       Author:         Harry E. Zhurov
#
#------------------------------------------------------------------------------

import os
import re
import subprocess
import tabulate
from   tabulate import tabulate as tab
from   utils    import *

tabulate.PRESERVE_WHITESPACE = True

#-------------------------------------------------------------------------------
#
#   Timing report
#
def timing_report(env):
    slack_pattern = 'Design Timing Summary[^$]+WNS\(ns\)\s+TNS\(ns\)\s+.+WHS\(ns\)\s+THS\(ns\).+\n[\s\-]+\n\s+(\-?[0-9\.]+)\s+(\-?[0-9\.]+)[\s\-]+([0-9\.]+)[\s\-]+([0-9\.]+)\s+(\-?[0-9\.]+)\s+(\-?[0-9\.]+)\s+'
    filepath = os.path.join(env['BUILD_SYN_PATH'], env['VIVADO_PROJECT_NAME'] + '.runs', 'impl_1', env['TOP_NAME'] + '_final_timing.rpt')
    if not os.path.exists(filepath):
        print( colorize('Timing Summary Report file does not exist', 'yellow', True) )
        return
        
    with open(filepath) as fn:
        contents = fn.read()
        
                
    columns  = ['WNS, ns', 'TNS, ns', 'WHS, ns', 'THS, ns']
    res = re.search(slack_pattern, contents)
    slacks_out = []
    if res:
        slacks = list(res.groups())
        del slacks[2:4]
        slacks_out.append([colorize(str(i), 'red', True) for i in slacks])
        
    env['TIMING_FAILURE'] = False
    for slack in slacks:
        if float(slack) < 0:
            env['TIMING_FAILURE'] = '| WNS: ' + slacks[0] + ' ns | TNS: ' + slacks[1] + ' ns | WHS: ' + slacks[2] + ' ns | THS: ' + slacks[3] + ' ns |'
            break
            
    out = str(tab(slacks_out, headers = [colorize(c, 'cyan', True) for c in columns], tablefmt='plain', stralign='left'))
    print('-'*60)
    print(' '*20, colorize('Timing', 'blue', True), os.linesep)
    print(out)
    
    timing_report_flag_name = os.path.join(env['BUILD_SYN_PATH'], env['VIVADO_PROJECT_NAME'] + '.runs', 'impl_1', 'TIMING_FAILURE')
    if os.path.exists(timing_report_flag_name):
        subprocess.run(['rm', timing_report_flag_name])
        
    if env['TIMING_FAILURE']:
        print(os.linesep + colorize('*'*55, 'yellow', True))
        print(colorize('*' + ' '*12 +'Timing requirements not met!' + ' '*13 + '*', 'yellow', True))
        print(colorize('*'*55, 'yellow', True), os.linesep)
        with open(timing_report_flag_name, 'w') as f:
            f.write(env['TIMING_FAILURE'] + os.linesep)

#-------------------------------------------------------------------------------
#
#    Resource utilization report
#
def utilization_report(env):
    
    # read report file
    filepath = os.path.join(env['BUILD_SYN_PATH'], env['VIVADO_PROJECT_NAME'] + '.runs', 'impl_1', env['TOP_NAME'] + '_final_utilization.rpt')
    if os.path.exists(filepath):
        with open(filepath) as fn:
            contents = fn.read()
    else:
        print( colorize('Final Utilization Report file does not exist', 'yellow', True) )
        return
    
    # processing utilization table header    
    header_cols    = ['Used', 'Available', 'Util%']
    header_pattern = '\|\s+Site Type\s+\|(.+\%)'
    
    res = re.search(header_pattern, contents)
    if res:
        cols = res.group(1)
        cols = [i.strip() for i in cols.split('|')]
    else:
        print( colorize('Invalid format of Final Utilization Report file', 'yellow', True) )
        return
        
    # generate search patterns
    subpattern = ''
    for i in cols[:-1]:   # except Util%
        if i in header_cols:
            grab = '(\d+)'
        else:
            grab = '\d+'
        subpattern += '\|\s+' + grab + '\s+'
        
    subpattern += '\|\s+([<0-9\.]+)\s+\|'
    
    
    patterns = { 
        'CLB'                : '\|\s+CLB\s+'                   + subpattern,
        'Slice'              : '\|\s+Slice\s+'                 + subpattern,
        'CLB LUT'            : '\|\s+CLB LUTs\s+'              + subpattern,
        'Slice LUT'          : '\|\s+Slice LUTs\s+'            + subpattern,
        '  LUT Logic'        : '\|\s+LUT as Logic\s+'          + subpattern,
        '  LUT RAM'          : '\|\s+LUT as Memory\s+'         + subpattern,
        'CLB Registers'      : '\|\s+CLB Registers\s+'         + subpattern,
        'Slice Registers'    : '\|\s+Slice Registers\s+'       + subpattern,
        '  FF'               : '\|\s+Register as Flip Flop\s+' + subpattern,
        '  LATCH'            : '\|\s+Register as Latch\s+'     + subpattern,
        'BUFG'               : '\|\s+GLOBAL CLOCK BUFFERs\s+'  + subpattern,
        'BUFGCTRL'           : '\|\s+BUFG.*\s+'                + subpattern,
        'PLL'                : '\|\s+PLL.+\s+'                 + subpattern,
        'MMCM'               : '\|\s+MMCM.+\s+'                + subpattern,
        'I/O'                : '\|\s+Bonded IOB\s+'            + subpattern,
        'GTH'                : '\|\s+GTH.+CHANNEL\s+'          + subpattern,
        'GTX'                : '\|\s+GTX.+CHANNEL\s+'          + subpattern,
        'GTY'                : '\|\s+GTY.+CHANNEL\s+'          + subpattern,
        'BRAM Tile'          : '\|\s+Block RAM Tile\s+'        + subpattern,
        '  RAMB36/FIFO'      : '\|\s+RAMB36/FIFO\*?\s+'        + subpattern,
        '    RAMB36E2 only'  : '\|\s+RAMB36E2 only\s+'         + subpattern,
        '  RAMB18'           : '\|\s+RAMB18\s+'                + subpattern,
        '    RAMB36E2 only'  : '\|\s+RAMB36E2 only\s+'         + subpattern,
        'URAM'               : '\|\s+URAM\s+'                  + subpattern
    }
    
    # output utilization summary    
    out = []
    for k in patterns:
        res = re.search(patterns[k], contents)
        if res:
            vals = [colorize(str(i), 'red', True) for i in res.groups()]
            out.append([colorize(k, 'white', True)] + vals)
        
    color   = 'cyan'
    columns = ['Resource', 'Used', 'Available', 'Utilization %']
            
    print('-'*60)
    print(' '*20, colorize('Utilization', 'blue', True), os.linesep)
    print(tab(out, headers=[colorize(c, color, True) for c in columns], tablefmt='plain', stralign='left'))
    print('')

#-------------------------------------------------------------------------------
#    
#   Log file filter 
#    
def log_file_filter(env):
    syn_logpath  = os.path.join(env['BUILD_SYN_PATH'], env['VIVADO_PROJECT_NAME'] + '.runs', 'synth_1', 'runme.log')
    impl_logpath = os.path.join(env['BUILD_SYN_PATH'], env['VIVADO_PROJECT_NAME'] + '.runs', 'impl_1',  'runme.log')
    
    warn_pattern             = '(WARNING:)(.+)'
    crit_warn_pattern        = '(CRITICAL WARNING:)(.+)'
    syn_elapsed_time_pattern = 'synth_design\:.+elapsed \= ([0-9\:]+)'
    syn_elapsed_time_pattern = 'synth_design\:.+elapsed \= ([0-9\:]+)'
    synlog  = ''
    impllog = ''

    if os.path.exists(syn_logpath):
        with open(syn_logpath, 'r') as lfile:
            synlog = lfile.read()
            
    if os.path.exists(impl_logpath):
        with open(impl_logpath, 'r') as lfile:
            impllog = lfile.read()
            
            
    syn_warn       = re.findall( warn_pattern,      synlog  )
    syn_crit_warn  = re.findall( crit_warn_pattern, synlog  )
    impl_warn      = re.findall( warn_pattern,      impllog )
    impl_crit_warn = re.findall( crit_warn_pattern, impllog )
    
    return syn_warn, syn_crit_warn, impl_warn, impl_crit_warn
    
#-------------------------------------------------------------------------------
def warning_report(env, opt='all'):
    syn_warn, syn_crit_warn, impl_warn, impl_crit_warn = log_file_filter(env)
    
    print('')
    print('-'*60)
    print(' '*20, colorize('Messages', 'blue', True), os.linesep)

    if 'syn' in opt or 'all' in opt:
        print('')
        print( colorize(' '*12 + 'Synthesis Warnings', 'white', True) )
        print('')
        for w in syn_warn:
            print( colorize(w[0], 'yellow', True), w[1] )
        for cw in syn_crit_warn:
            print( colorize(cw[0], 'yellow', True), cw[1] )

    if 'impl' in opt or 'all' in opt:
        print('')
        print( colorize(' '*12 + 'Implementation Warnings', 'white', True) )
        print('')
        for w in impl_warn:
            print( colorize(w[0], 'yellow', True), w[1] )
        for cw in impl_crit_warn:
            print( colorize(cw[0], 'yellow', True), cw[1] )

    color   = 'cyan'
    columns = ['Message Type', 'Synthesis', 'Implementation']

    syn_wcount  = len(syn_warn)
    syn_cwcount = len(syn_crit_warn)
    if syn_wcount:
        syn_wcount = colorize(str(syn_wcount), 'red', True)
    else:
        syn_wcount = '-'
    
    if syn_cwcount:
        syn_cwcount = colorize(str(syn_cwcount), 'red', True)
    else:
        syn_cwcount = '-'
    
    impl_wcount  = len(impl_warn)
    impl_cwcount = len(impl_crit_warn)
    if impl_wcount:
        impl_wcount = colorize(str(impl_wcount), 'red', True)
    else:
        impl_wcount = '-'

    if impl_cwcount:
        impl_cwcount = colorize(str(impl_cwcount), 'red', True)
    else:
        impl_cwcount = '-'
        
                
    warn      = [colorize('Warnings         ', 'yellow', True), syn_wcount , impl_wcount] 
    crit_warn = [colorize('Critical Warnings', 'yellow', True), syn_cwcount, impl_cwcount]

    print('')
    print( colorize(' '*12 + 'Warning Summary', 'white', True) )
    print('')
    print(tab([warn, crit_warn], headers=[colorize(c, color, True) for c in columns], tablefmt='plain', stralign='center'))
    print('-'*60)
    print('')
    
#-------------------------------------------------------------------------------
    
