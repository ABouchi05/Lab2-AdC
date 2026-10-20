`timescale 1ns/1ps
module tb;
 reg clk=0; always #20 clk=~clk;
 reg [3:0] buttons=0;
 wire [3:0] leds;
 pochoco_soc #(.MemFile("build/sim.hex"), .EnableSPI(0)) dut (
 .i_Clk(clk),.i_Switch(buttons),.o_LED(leds),
 .i_SPI_SCLK(1'b0),.i_SPI_MOSI(1'b0),.i_SPI_CS_n(1'b1));
 integer round_num,sum_ticks=0,n,elapsed,ticks,tens,ones,changes=0;
 reg [3:0] target,last_target=0;
 task clocks(input integer amount);
   begin repeat(amount) @(negedge clk); end
 endtask
 task wait_led(input [3:0] value);
   begin n=0; while(leds!==value && n<200000) begin clocks(1); n=n+1; end
   if(n==200000) $fatal(1,"Timeout LED %h PC=%h",value,dut.u_core.pc_id);
   end
 endtask
 task wait_target;
   begin n=0;
     while(!(leds==1 || leds==2 || leds==4 || leds==8) && n<200000) begin clocks(1); n=n+1; end
     if(n==200000) $fatal(1,"Timeout objetivo PC=%h",dut.u_core.pc_id);
     target=leds;
   end
 endtask
 // Modelar x0 no inicializado: el reset debe repararlo fisicamente.
 initial begin
   #1;
   dut.u_core.u_rf.u_bankA.u_lo.memory[0]=16'hdead;
   dut.u_core.u_rf.u_bankA.u_hi.memory[0]=16'hbeef;
   dut.u_core.u_rf.u_bankB.u_lo.memory[0]=16'h1234;
   dut.u_core.u_rf.u_bankB.u_hi.memory[0]=16'h5678;
   clocks(100);
   if(dut.u_core.u_rf.u_bankA.u_lo.memory[0]!==0 ||
      dut.u_core.u_rf.u_bankA.u_hi.memory[0]!==0 ||
      dut.u_core.u_rf.u_bankB.u_lo.memory[0]!==0 ||
      dut.u_core.u_rf.u_bankB.u_hi.memory[0]!==0)
     $fatal(1,"Reset no inicializa x0");
 end
 initial begin
   clocks(65540); wait_led(15); clocks(29900);
   if(leds!==15) $fatal(1,"Espera inicial demasiado corta");
   wait_target;
   clocks(1600); buttons=15; clocks(300); buttons=0;
   wait_led(0);
   if(dut.u_periph.digit_q!==8'hee) $fatal(1,"Error no mostrado");
   wait_led(15);
   for(round_num=0;round_num<10;round_num=round_num+1) begin
     wait_target;
     if(round_num==3) begin
       clocks(1200); buttons=15; clocks(300); buttons=0;
       wait_led(0);
       if(dut.u_periph.digit_q!==8'hee) $fatal(1,"Error intermedio no mostrado");
       wait_led(15); wait_target;
     end
     if(target!=last_target) changes=changes+1;
     last_target=target;
     clocks(1500+round_num*127); buttons=target;
     clocks(150); elapsed=dut.u_periph.elapsed_q; ticks=elapsed/1000;
     sum_ticks=sum_ticks+ticks; buttons=0;
     wait_led(0);
     tens=(ticks>99 ? 99 : ticks)/10; ones=(ticks>99 ? 99 : ticks)%10;
     if(dut.u_periph.digit_q!==((tens<<4)|ones)) $fatal(1,"Tiempo incorrecto ronda %0d",round_num);
     if(round_num<9) wait_led(15);
   end
   clocks(16000); ticks=sum_ticks/10;
   if(dut.u_periph.digit_q!==(((ticks/10)<<4)|(ticks%10))) $fatal(1,"Promedio incorrecto");
   if(changes<2) $fatal(1,"Seleccion no varia");
   buttons=1; clocks(500); buttons=0; wait_led(15);
   $display("PASS: espera, error, 10 rondas, tiempos, promedio, variacion y reinicio");
   $finish;
 end
 initial begin #200000000; $fatal(1,"Timeout global"); end
endmodule
