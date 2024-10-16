pub const teilnehmer = .{
    .{ .name="Tigger", .vorname="Sammy", .Zelte_id=1},
    .{ .name="beep", .vorname="beep", .Zelte_id=2},
    .{ .name="Bam", .vorname="Theodore", .Zelte_id=1},
    .{ .name="cropp", .vorname="friedrich", .Zelte_id=2},
    .{ .name="floep", .vorname="balthasar", .Zelte_id=3},
    .{ .name="blerp", .vorname="goodman", .Zelte_id=1},
    .{ .name="shoop", .vorname="heep", .Zelte_id=4},
    .{ .name="Bammy", .vorname="Ludwig", .Zelte_id=1},
    .{ .name="coco", .vorname="Stue", .Zelte_id=2},
    .{ .name="cocojo", .vorname="Lue", .Zelte_id=3},
    .{ .name="Tiggeiir", .vorname="Sammy", .Zelte_id=1},
    .{ .name="beeoqqp", .vorname="beep", .Zelte_id=2},
    .{ .name="Baojlmm", .vorname="Theodore", .Zelte_id=1},
    .{ .name="croooqwppp", .vorname="friedrich", .Zelte_id=2},
    .{ .name="floowejep", .vorname="balthasar", .Zelte_id=3},
    .{ .name="bleroowpp", .vorname="goodman", .Zelte_id=1},
    .{ .name="shooowwp", .vorname="heep", .Zelte_id=4},
    .{ .name="Bamowimy", .vorname="Ludwig", .Zelte_id=1},
    .{ .name="cochioo", .vorname="Stuooe", .Zelte_id=2},
    .{ .name="cocoamelo", .vorname="Lwoue", .Zelte_id=3},
    .{ .name="oqwppp", .vorname="friedrich", .Zelte_id=2},
    .{ .name="floiijep", .vorname="balthasar", .Zelte_id=3},
    .{ .name="bleroowpp", .vorname="goodman", .Zelte_id=1},
    .{ .name="swwp", .vorname="heep", .Zelte_id=4},
    .{ .name="Bamowimy", .vorname="Ludwig", .Zelte_id=1},
    .{ .name="cochioo", .vorname="Stuooe", .Zelte_id=2},
    .{ .name="clo", .vorname="Lwoue", .Zelte_id=3},
    .{ .name="cppp", .vorname="friedrich", .Zelte_id=2},
    .{ .name="fep", .vorname="balthasar", .Zelte_id=3},
    .{ .name="bpp", .vorname="goodman", .Zelte_id=1},
    .{ .name="sp", .vorname="heep", .Zelte_id=4},
    .{ .name="By", .vorname="Ludwig", .Zelte_id=1},
    .{ .name="coco", .vorname="Stuooe", .Zelte_id=2},
    .{ .name="cocelo", .vorname="Lwoue", .Zelte_id=3},
};
pub const zelte = .{
//    .{ .id=0, .plaetze = 60 },
    .{ .id=1, .plaetze = 4 },
    .{ .id=2, .plaetze = 2 },
    .{ .id=3, .plaetze = 5 },
    .{ .id=4, .plaetze = 5 },
    .{ .id=5, .plaetze = 5 },
    .{ .id=6, .plaetze = 5 },
};
pub const db_structure = struct{
    Zelte: struct {
        id: ?u32, 
        plaetze: u8
    },
    Teilnehmer: struct {
        id: u32, 
        name: []u8 ,
        vorname: []u8, 
        Zelte_id: ?u8,
    },
    Allergene: struct {
        id: u8,  
        name: []u8
    },
    Teilnehmer_Allergene: struct {
        Teilnehmer_id: u32,
        Allergene_id: u8, 
    }
};
pub const teilnehmer_allergene = .{
    .{.Teilnehmer_id = 1, .Allergene_id = 'A'},    
    .{.Teilnehmer_id = 1, .Allergene_id = 'P'},    
    .{.Teilnehmer_id = 1, .Allergene_id = 'B'},    
    .{.Teilnehmer_id = 2, .Allergene_id = 'A'},    
    .{.Teilnehmer_id = 1, .Allergene_id = 'A'},    
    .{.Teilnehmer_id = 1, .Allergene_id = 'C'},    
    .{.Teilnehmer_id = 2, .Allergene_id = 'C'},    
    .{.Teilnehmer_id = 3, .Allergene_id = 'P'},    
    .{.Teilnehmer_id = 5, .Allergene_id = 'D'},    
    .{.Teilnehmer_id = 8, .Allergene_id = 'R'},    
    .{.Teilnehmer_id = 5, .Allergene_id = 'R'}
};
//pub const teilnehmer =
//  \\Tigger,Sammy,1
//  \\beep,beep,e
//  \\Bam,Theodore,1
//  \\cropp,friedrich,2
//  \\floep,balthasar,3
//  \\blerp,goodman,1
//  \\shoop,heep,4
//  \\Bammy,Ludwig,1
//  \\coco,Stue,2
//  \\cocojo,Lue,3
//  \\Tiggeiir,Sammy,1
//  \\beeoqqp,beep,e
//  \\Baojlmm,Theodore,1
//  \\croooqwppp,friedrich,2
//  \\floowejep,balthasar,3
//  \\bleroowpp,goodman,1
//  \\shooowwp,heep,4
//  \\Bamowimy,Ludwig,1
//  \\cochioo,Stuooe,2
//  \\cocoamelo,Lwoue,3
//  \\oqwppp,friedrich,2
//  \\floiijep,balthasar,3
//  \\bleroowpp,goodman,1
//  \\swwp,heep,4
//  \\Bamowimy,Ludwig,1
//  \\cochioo,Stuooe,2
//  \\clo,Lwoue,3
//  \\cppp,friedrich,2
//  \\fep,balthasar,3
//  \\bpp,goodman,1
//  \\sp,heep,4
//  \\By,Ludwig,1
//  \\coco,Stuooe,2
//  \\cocelo,Lwoue,3
//  ;



pub const allergene = .{
    .{ .id = 'A', .name = "Gluten" },
    .{ .id = 'B', .name = "Krebstiere" },
    .{ .id = 'C', .name = "Vogel Eier" },
    .{ .id = 'D', .name = "Fisch" },
    .{ .id = 'E', .name = "Erdnuesse" },
    .{ .id = 'F', .name = "Sojabohnen" },
    .{ .id = 'G', .name = "Laktose" },
    .{ .id = 'H', .name = "Schalenfruechte" },
    .{ .id = 'L', .name = "Sellerie" },
    .{ .id = 'M', .name = "Senf" },
    .{ .id = 'N', .name = "Sesam" },
    .{ .id = 'O', .name = "Sulfite" },
    .{ .id = 'P', .name = "Lupinen" },
    .{ .id = 'R', .name = "Weichtiere" },
    .{ .id = 'V', .name = "Vegan" },
    .{ .id = 'W', .name = "Vegetarisch" },
};

