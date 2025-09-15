module tb_crc32();
    parameter SLICE_LENGTH = 4;
    parameter INITIAL_CRC = 32'hFFFFFFFF;
    parameter INVERT_OUTPUT = 1;
    parameter REGISTER_OUTPUT = 1;
    parameter MAX_SLICE_LENGTH = 16;
    
    parameter CLK_PERIOD = 10;
    
    reg clk;
    reg rst;
    reg [8*SLICE_LENGTH-1:0] in_data;
    reg [SLICE_LENGTH-1:0] in_valid;
    wire [31:0] out_crc;
    
    reg [7:0] test_data [0:511];
    integer test_data_length;
    
    crc32 #(
        .SLICE_LENGTH(SLICE_LENGTH),
        .INITIAL_CRC(INITIAL_CRC),
        .INVERT_OUTPUT(INVERT_OUTPUT),
        .REGISTER_OUTPUT(REGISTER_OUTPUT),
        .MAX_SLICE_LENGTH(MAX_SLICE_LENGTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .in_data(in_data),
        .in_valid(in_valid),
        .out_crc(out_crc)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        test_data[0] = 8'd178; test_data[1] = 8'd143; test_data[2] = 8'd193; test_data[3] = 8'd111;
        test_data[4] = 8'd188; test_data[5] = 8'd188; test_data[6] = 8'd22; test_data[7] = 8'd210;
        test_data[8] = 8'd105; test_data[9] = 8'd207; test_data[10] = 8'd200; test_data[11] = 8'd183;
        test_data[12] = 8'd224; test_data[13] = 8'd107; test_data[14] = 8'd47; test_data[15] = 8'd176;
        test_data[16] = 8'd58; test_data[17] = 8'd131; test_data[18] = 8'd251; test_data[19] = 8'd161;
        test_data[20] = 8'd231; test_data[21] = 8'd204; test_data[22] = 8'd176; test_data[23] = 8'd123;
        test_data[24] = 8'd31; test_data[25] = 8'd66; test_data[26] = 8'd136; test_data[27] = 8'd30;
        test_data[28] = 8'd49; test_data[29] = 8'd122; test_data[30] = 8'd6; test_data[31] = 8'd218;
        test_data[32] = 8'd175; test_data[33] = 8'd98; test_data[34] = 8'd211; test_data[35] = 8'd115;
        test_data[36] = 8'd47; test_data[37] = 8'd49; test_data[38] = 8'd213; test_data[39] = 8'd108;
        test_data[40] = 8'd185; test_data[41] = 8'd244; test_data[42] = 8'd198; test_data[43] = 8'd92;
        test_data[44] = 8'd49; test_data[45] = 8'd56; test_data[46] = 8'd34; test_data[47] = 8'd154;
        test_data[48] = 8'd6; test_data[49] = 8'd126; test_data[50] = 8'd203; test_data[51] = 8'd117;
        test_data[52] = 8'd178; test_data[53] = 8'd59; test_data[54] = 8'd131; test_data[55] = 8'd80;
        test_data[56] = 8'd88; test_data[57] = 8'd209; test_data[58] = 8'd109; test_data[59] = 8'd222;
        test_data[60] = 8'd21; test_data[61] = 8'd18; test_data[62] = 8'd135; test_data[63] = 8'd69;
        test_data[64] = 8'd185; test_data[65] = 8'd116; test_data[66] = 8'd31; test_data[67] = 8'd165;
        test_data[68] = 8'd101; test_data[69] = 8'd41; test_data[70] = 8'd169; test_data[71] = 8'd84;
        test_data[72] = 8'd91; test_data[73] = 8'd5; test_data[74] = 8'd28; test_data[75] = 8'd41;
        test_data[76] = 8'd187; test_data[77] = 8'd116; test_data[78] = 8'd214; test_data[79] = 8'd134;
        test_data[80] = 8'd45; test_data[81] = 8'd124; test_data[82] = 8'd16; test_data[83] = 8'd196;
        test_data[84] = 8'd98; test_data[85] = 8'd111; test_data[86] = 8'd247; test_data[87] = 8'd243;
        test_data[88] = 8'd33; test_data[89] = 8'd13; test_data[90] = 8'd114; test_data[91] = 8'd11;
        test_data[92] = 8'd166; test_data[93] = 8'd53; test_data[94] = 8'd11; test_data[95] = 8'd28;
        test_data[96] = 8'd137; test_data[97] = 8'd2; test_data[98] = 8'd103; test_data[99] = 8'd203;
        test_data[100] = 8'd62; test_data[101] = 8'd161; test_data[102] = 8'd157; test_data[103] = 8'd197;
        test_data[104] = 8'd48; test_data[105] = 8'd145; test_data[106] = 8'd60; test_data[107] = 8'd81;
        test_data[108] = 8'd19; test_data[109] = 8'd11; test_data[110] = 8'd45; test_data[111] = 8'd213;
        test_data[112] = 8'd37; test_data[113] = 8'd247; test_data[114] = 8'd143; test_data[115] = 8'd255;
        test_data[116] = 8'd210; test_data[117] = 8'd134; test_data[118] = 8'd214; test_data[119] = 8'd38;
        test_data[120] = 8'd199; test_data[121] = 8'd197; test_data[122] = 8'd123; test_data[123] = 8'd91;
        test_data[124] = 8'd17; test_data[125] = 8'd196; test_data[126] = 8'd92; test_data[127] = 8'd173;
        test_data[128] = 8'd24; test_data[129] = 8'd14; test_data[130] = 8'd92; test_data[131] = 8'd241;
        test_data[132] = 8'd153; test_data[133] = 8'd106; test_data[134] = 8'd39; test_data[135] = 8'd167;
        test_data[136] = 8'd173; test_data[137] = 8'd114; test_data[138] = 8'd33; test_data[139] = 8'd103;
        test_data[140] = 8'd112; test_data[141] = 8'd10; test_data[142] = 8'd36; test_data[143] = 8'd68;
        test_data[144] = 8'd122; test_data[145] = 8'd225; test_data[146] = 8'd51; test_data[147] = 8'd214;
        test_data[148] = 8'd215; test_data[149] = 8'd111; test_data[150] = 8'd181; test_data[151] = 8'd128;
        test_data[152] = 8'd167; test_data[153] = 8'd33; test_data[154] = 8'd90; test_data[155] = 8'd2;
        test_data[156] = 8'd61; test_data[157] = 8'd47; test_data[158] = 8'd134; test_data[159] = 8'd138;
        test_data[160] = 8'd135; test_data[161] = 8'd114; test_data[162] = 8'd135; test_data[163] = 8'd20;
        test_data[164] = 8'd193; test_data[165] = 8'd113; test_data[166] = 8'd190; test_data[167] = 8'd101;
        test_data[168] = 8'd235; test_data[169] = 8'd187; test_data[170] = 8'd70; test_data[171] = 8'd201;
        test_data[172] = 8'd222; test_data[173] = 8'd118; test_data[174] = 8'd18; test_data[175] = 8'd231;
        test_data[176] = 8'd154; test_data[177] = 8'd183; test_data[178] = 8'd187; test_data[179] = 8'd9;
        test_data[180] = 8'd133; test_data[181] = 8'd51; test_data[182] = 8'd84; test_data[183] = 8'd112;
        test_data[184] = 8'd115; test_data[185] = 8'd208; test_data[186] = 8'd141; test_data[187] = 8'd193;
        test_data[188] = 8'd165; test_data[189] = 8'd119; test_data[190] = 8'd211; test_data[191] = 8'd144;
        test_data[192] = 8'd105; test_data[193] = 8'd250; test_data[194] = 8'd154; test_data[195] = 8'd49;
        test_data[196] = 8'd22; test_data[197] = 8'd60; test_data[198] = 8'd123; test_data[199] = 8'd4;
        test_data[200] = 8'd70; test_data[201] = 8'd235; test_data[202] = 8'd181; test_data[203] = 8'd143;
        test_data[204] = 8'd36; test_data[205] = 8'd98; test_data[206] = 8'd31; test_data[207] = 8'd48;
        test_data[208] = 8'd50; test_data[209] = 8'd73; test_data[210] = 8'd122; test_data[211] = 8'd128;
        test_data[212] = 8'd255; test_data[213] = 8'd39; test_data[214] = 8'd240; test_data[215] = 8'd197;
        test_data[216] = 8'd187; test_data[217] = 8'd237; test_data[218] = 8'd13; test_data[219] = 8'd243;
        test_data[220] = 8'd34; test_data[221] = 8'd169; test_data[222] = 8'd227; test_data[223] = 8'd38;
        test_data[224] = 8'd213; test_data[225] = 8'd207; test_data[226] = 8'd125; test_data[227] = 8'd245;
        test_data[228] = 8'd110; test_data[229] = 8'd239; test_data[230] = 8'd137; test_data[231] = 8'd31;
        test_data[232] = 8'd97; test_data[233] = 8'd210; test_data[234] = 8'd49; test_data[235] = 8'd54;
        test_data[236] = 8'd250; test_data[237] = 8'd65; test_data[238] = 8'd66; test_data[239] = 8'd86;
        test_data[240] = 8'd138; test_data[241] = 8'd124; test_data[242] = 8'd23; test_data[243] = 8'd171;
        test_data[244] = 8'd8; test_data[245] = 8'd117; test_data[246] = 8'd62; test_data[247] = 8'd37;
        test_data[248] = 8'd189; test_data[249] = 8'd9; test_data[250] = 8'd122; test_data[251] = 8'd237;
        test_data[252] = 8'd35; test_data[253] = 8'd9; test_data[254] = 8'd212; test_data[255] = 8'd70;
        test_data[256] = 8'd189; test_data[257] = 8'd107; test_data[258] = 8'd10; test_data[259] = 8'd213;
        test_data[260] = 8'd63; test_data[261] = 8'd236; test_data[262] = 8'd23; test_data[263] = 8'd153;
        test_data[264] = 8'd45; test_data[265] = 8'd136; test_data[266] = 8'd180; test_data[267] = 8'd44;
        test_data[268] = 8'd40; test_data[269] = 8'd252; test_data[270] = 8'd180; test_data[271] = 8'd140;
        test_data[272] = 8'd229; test_data[273] = 8'd40; test_data[274] = 8'd120; test_data[275] = 8'd180;
        test_data[276] = 8'd215; test_data[277] = 8'd211; test_data[278] = 8'd41; test_data[279] = 8'd77;
        test_data[280] = 8'd29; test_data[281] = 8'd203; test_data[282] = 8'd16; test_data[283] = 8'd70;
        test_data[284] = 8'd189; test_data[285] = 8'd69; test_data[286] = 8'd75; test_data[287] = 8'd50;
        test_data[288] = 8'd135; test_data[289] = 8'd11; test_data[290] = 8'd118; test_data[291] = 8'd214;
        test_data[292] = 8'd11; test_data[293] = 8'd126; test_data[294] = 8'd32; test_data[295] = 8'd7;
        test_data[296] = 8'd245; test_data[297] = 8'd80; test_data[298] = 8'd51; test_data[299] = 8'd244;
        test_data[300] = 8'd29; test_data[301] = 8'd99; test_data[302] = 8'd129; test_data[303] = 8'd190;
        test_data[304] = 8'd226; test_data[305] = 8'd189; test_data[306] = 8'd133; test_data[307] = 8'd85;
        test_data[308] = 8'd255; test_data[309] = 8'd161; test_data[310] = 8'd79; test_data[311] = 8'd7;
        test_data[312] = 8'd95; test_data[313] = 8'd1; test_data[314] = 8'd141; test_data[315] = 8'd149;
        test_data[316] = 8'd119; test_data[317] = 8'd95; test_data[318] = 8'd103; test_data[319] = 8'd255;
        test_data[320] = 8'd136; test_data[321] = 8'd254; test_data[322] = 8'd40; test_data[323] = 8'd221;
        test_data[324] = 8'd31; test_data[325] = 8'd158; test_data[326] = 8'd46; test_data[327] = 8'd161;
        test_data[328] = 8'd146; test_data[329] = 8'd95; test_data[330] = 8'd221; test_data[331] = 8'd229;
        test_data[332] = 8'd196; test_data[333] = 8'd228; test_data[334] = 8'd12; test_data[335] = 8'd249;
        test_data[336] = 8'd25; test_data[337] = 8'd173; test_data[338] = 8'd160; test_data[339] = 8'd107;
        test_data[340] = 8'd32; test_data[341] = 8'd128; test_data[342] = 8'd125; test_data[343] = 8'd143;
        test_data[344] = 8'd169; test_data[345] = 8'd67; test_data[346] = 8'd43; test_data[347] = 8'd148;
        test_data[348] = 8'd7; test_data[349] = 8'd29; test_data[350] = 8'd195; test_data[351] = 8'd137;
        test_data[352] = 8'd35; test_data[353] = 8'd49; test_data[354] = 8'd42; test_data[355] = 8'd32;
        test_data[356] = 8'd44; test_data[357] = 8'd173; test_data[358] = 8'd48; test_data[359] = 8'd60;
        test_data[360] = 8'd58; test_data[361] = 8'd39; test_data[362] = 8'd12; test_data[363] = 8'd226;
        test_data[364] = 8'd57; test_data[365] = 8'd165; test_data[366] = 8'd73; test_data[367] = 8'd119;
        test_data[368] = 8'd214; test_data[369] = 8'd165; test_data[370] = 8'd93; test_data[371] = 8'd59;
        test_data[372] = 8'd81; test_data[373] = 8'd237; test_data[374] = 8'd11; test_data[375] = 8'd200;
        test_data[376] = 8'd213; test_data[377] = 8'd115; test_data[378] = 8'd250; test_data[379] = 8'd125;
        test_data[380] = 8'd181; test_data[381] = 8'd221; test_data[382] = 8'd232; test_data[383] = 8'd165;
        test_data[384] = 8'd133; test_data[385] = 8'd191; test_data[386] = 8'd13; test_data[387] = 8'd233;
        test_data[388] = 8'd109; test_data[389] = 8'd35; test_data[390] = 8'd234; test_data[391] = 8'd192;
        test_data[392] = 8'd45; test_data[393] = 8'd83; test_data[394] = 8'd101; test_data[395] = 8'd205;
        test_data[396] = 8'd239; test_data[397] = 8'd82; test_data[398] = 8'd160; test_data[399] = 8'd28;
        test_data[400] = 8'd70; test_data[401] = 8'd68; test_data[402] = 8'd99; test_data[403] = 8'd48;
        test_data[404] = 8'd76; test_data[405] = 8'd156; test_data[406] = 8'd161; test_data[407] = 8'd247;
        test_data[408] = 8'd202; test_data[409] = 8'd57; test_data[410] = 8'd245; test_data[411] = 8'd132;
        test_data[412] = 8'd238; test_data[413] = 8'd104; test_data[414] = 8'd161; test_data[415] = 8'd161;
        test_data[416] = 8'd248; test_data[417] = 8'd150; test_data[418] = 8'd230; test_data[419] = 8'd135;
        test_data[420] = 8'd140; test_data[421] = 8'd235; test_data[422] = 8'd226; test_data[423] = 8'd235;
        test_data[424] = 8'd0; test_data[425] = 8'd36; test_data[426] = 8'd232; test_data[427] = 8'd23;
        test_data[428] = 8'd47; test_data[429] = 8'd55; test_data[430] = 8'd27; test_data[431] = 8'd251;
        test_data[432] = 8'd121; test_data[433] = 8'd10; test_data[434] = 8'd93; test_data[435] = 8'd242;
        test_data[436] = 8'd77; test_data[437] = 8'd154; test_data[438] = 8'd4; test_data[439] = 8'd9;
        test_data[440] = 8'd38; test_data[441] = 8'd13; test_data[442] = 8'd46; test_data[443] = 8'd185;
        test_data[444] = 8'd146; test_data[445] = 8'd80; test_data[446] = 8'd114; test_data[447] = 8'd34;
        test_data[448] = 8'd208; test_data[449] = 8'd220; test_data[450] = 8'd240; test_data[451] = 8'd175;
        test_data[452] = 8'd25; test_data[453] = 8'd66; test_data[454] = 8'd9; test_data[455] = 8'd3;
        test_data[456] = 8'd133; test_data[457] = 8'd143; test_data[458] = 8'd143; test_data[459] = 8'd238;
        test_data[460] = 8'd4; test_data[461] = 8'd92; test_data[462] = 8'd25; test_data[463] = 8'd56;
        test_data[464] = 8'd86; test_data[465] = 8'd74; test_data[466] = 8'd17; test_data[467] = 8'd153;
        test_data[468] = 8'd227; test_data[469] = 8'd53; test_data[470] = 8'd86; test_data[471] = 8'd127;
        test_data[472] = 8'd144; test_data[473] = 8'd110; test_data[474] = 8'd104; test_data[475] = 8'd178;
        test_data[476] = 8'd229; test_data[477] = 8'd214; test_data[478] = 8'd214; test_data[479] = 8'd156;
        test_data[480] = 8'd188; test_data[481] = 8'd97; test_data[482] = 8'd47; test_data[483] = 8'd174;
        test_data[484] = 8'd75; test_data[485] = 8'd217; test_data[486] = 8'd244; test_data[487] = 8'd137;
        test_data[488] = 8'd147; test_data[489] = 8'd173; test_data[490] = 8'd128; test_data[491] = 8'd38;
        test_data[492] = 8'd117; test_data[493] = 8'd170; test_data[494] = 8'd188; test_data[495] = 8'd8;
        test_data[496] = 8'd113; test_data[497] = 8'd123; test_data[498] = 8'd238; test_data[499] = 8'd238;
        test_data[500] = 8'd71; test_data[501] = 8'd195; test_data[502] = 8'd86; test_data[503] = 8'd222;
        test_data[504] = 8'd154; test_data[505] = 8'd198; test_data[506] = 8'd110; test_data[507] = 8'd45;
        test_data[508] = 8'd146; 
        test_data_length = 509; 
    end
    integer i, j;
    reg [31:0] expected_crc;
    
    initial begin
        $display("Starting CRC32 Testbench");
        in_data = 0;
        in_valid = 0;
        rst = 1;
        
        expected_crc = 32'h123d03ad; 
        
        @(posedge clk);
        @(posedge clk);
        rst = 0;
        @(posedge clk);
        
        for (i = 0; i < test_data_length; i = i + SLICE_LENGTH) begin
            in_data = 0;
            in_valid = 0;
            
            for (j = 0; j < SLICE_LENGTH && (i + j) < test_data_length; j = j + 1) begin
                in_data[8*j +: 8] = test_data[i + j];
                in_valid[j] = 1'b1;
            end
            
            $display("Cycle %0d: Sending bytes %0d-%0d", i/SLICE_LENGTH, i, i+j-1);
            $display("  in_data = 0x%h", in_data);
            $display("  in_valid = %b", in_valid);
            
            @(posedge clk);
        end
        
        in_valid = 0;
        
        if (REGISTER_OUTPUT) begin
            @(posedge clk);
        end
        
        $display("Final CRC: 0x%08x", out_crc);
        $display("Expected : 0x%08x", expected_crc);
        if (out_crc == expected_crc) begin
            $display("TEST PASSED!");
        end else begin
            $display("TEST FAILED!");
        end
        
        #100;
        $finish;
    end
        
endmodule