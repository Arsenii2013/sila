class Globals;

    local semaphore display_key = new(1);
    local NetworkConfiguration network_conf = new();

    protected static Globals singleton;
    protected function new(); endfunction

    static function Globals get();
        if(singleton == null)
            singleton = new();
        return singleton;
    endfunction

    static function NetworkConfiguration get_network_configuration();
        return get().network_conf;
    endfunction

    static function semaphore get_display_key();
        return get().display_key;
    endfunction
endclass