from peakrdl_regblock.cpuif.axi4lite import AXI4Lite_Cpuif

class My_AXI4Lite(AXI4Lite_Cpuif):
    @property
    def port_declaration(self) -> str:
        # Override the port declaration text to use the alternate interface name and modport style
        return "axi4_lite_if.s s_axil"

    def signal(self, name:str) -> str:
        # Override the signal names to be lowercase instead
        return "s_axil." + name.lower()