unsigned global_sv_mode = 0;

void set_global_sv_mode(unsigned write_val){
    global_sv_mode = write_val;
}

unsigned get_global_sv_mode(void){
    return global_sv_mode;
}
