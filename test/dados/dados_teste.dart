//arquivo teste, ignora ele diogo.
import 'package:caderno_fazenda/models/talhao.dart';
import 'package:caderno_fazenda/models/area.dart';
import 'package:caderno_fazenda/models/aplicador.dart';
import 'package:caderno_fazenda/models/bomba_costal.dart';
import 'package:caderno_fazenda/models/drone.dart';
import 'package:caderno_fazenda/models/insumo.dart';

//====================================AREAS===================================================

Area sede() {
  return Area(nome: "Sede", id: 1);
}

//==================TALHOES=====================================================================

Talhao chico1(Area s) {
  return Talhao(nome: "Chico1", id: 1, hectares: 2.80, area: s);
}

Talhao chico2(Area s) {
  return Talhao(nome: "Chico2", id: 2, hectares: 3.80, area: s);
}

Talhao pinheiro(Area s) {
  return Talhao(nome: "Pinheiro", id: 3, hectares: 2.05, area: s);
}

Talhao engenho(Area s) {
  return Talhao(nome: "Engenho", id: 4, hectares: 4.90, area: s);
}

Talhao cafeVelho(Area s) {
  return Talhao(nome: "Cafe Velho", id: 5, hectares: 6.40, area: s);
}

//area s nome da funcao, sempre atribuir o objeto a ela
//=================================APLICADOR====================
Aplicador drone() {
  return Drone(
    id: 1,
    modelo: "DJI",
    // 70 L / 70 kg mantido conforme dados de teste da equipe (briefing cita 60 L / 70 kg)
    capacidadeMaximaL: 70,
    capacidadeMaximaKg: 70,
  );
}

Aplicador costal1() {
  return BombaCostal(
    id: 2,
    modelo: "Jacto",
    capacidadeMaximaL: 20,
    capacidadeMaximaKg: 20,
  );
}

Aplicador costal2() {
  return BombaCostal(
    id: 3,
    modelo: "Jacto",
    capacidadeMaximaL: 20,
    capacidadeMaximaKg: 20,
  );
}

Aplicador costal3() {
  return BombaCostal(
    id: 4,
    modelo: "Jacto",
    capacidadeMaximaL: 20,
    capacidadeMaximaKg: 20,
  );
}

Aplicador costal4() {
  return BombaCostal(
    id: 5,
    modelo: "Jacto",
    capacidadeMaximaL: 20,
    capacidadeMaximaKg: 20,
  );
}

Aplicador costal5() {
  return BombaCostal(
    id: 6,
    modelo: "Jacto",
    capacidadeMaximaL: 20,
    capacidadeMaximaKg: 20,
  );
}

Aplicador costal6() {
  return BombaCostal(
    id: 7,
    modelo: "Jacto",
    capacidadeMaximaL: 20,
    capacidadeMaximaKg: 20,
  );
}

Aplicador costal7() {
  return BombaCostal(
    id: 8,
    modelo: "Jacto",
    capacidadeMaximaL: 20,
    capacidadeMaximaKg: 20,
  );
}

Aplicador costal8() {
  return BombaCostal(
    id: 9,
    modelo: "Jacto",
    capacidadeMaximaL: 20,
    capacidadeMaximaKg: 20,
  );
}

Aplicador costal9() {
  return BombaCostal(
    id: 10,
    modelo: "Jacto",
    capacidadeMaximaL: 20,
    capacidadeMaximaKg: 20,
  );
}

Aplicador costal10() {
  return BombaCostal(
    id: 11,
    modelo: "Jacto",
    capacidadeMaximaL: 20,
    capacidadeMaximaKg: 20,
  );
}

//===============================INSUMOS==========================

Insumo bio() {
  return Insumo(nome: "BioKiller", id: 1, tipo: "Inseticida");
}

Insumo amma() {
  return Insumo(nome: "Ammoles", id: 2, tipo: "condicionador");
}

Insumo aca() {
  return Insumo(nome: "Acanne", id: 3, tipo: "Biostimulante");
}

Insumo pol() {
  return Insumo(nome: "Polme", id: 4, tipo: "Biostimulante");
}

Insumo calcio() {
  return Insumo(nome: "Alfol Calcio", id: 5, tipo: "Fertilizante");
}

Insumo bozo() {
  return Insumo(nome: "Alfol Boro", id: 6, tipo: "Fertilizante");
}

Insumo best() {
  return Insumo(nome: "Coda Best", id: 7, tipo: "Biostimulante");
}

Insumo eros() {
  return Insumo(nome: "Coda Eros", id: 8, tipo: "Biostimulante");
}

Insumo drip() {
  return Insumo(nome: "Coda Drip", id: 9, tipo: "Biostimulante");
}

Insumo harmo() {
  return Insumo(nome: "Coda Harmony", id: 10, tipo: "Biostimulante");
}

Insumo spill() {
  return Insumo(nome: "Coda Spill", id: 11, tipo: "Biostimulante");
}

Insumo valu() {
  return Insumo(nome: "Valuva", id: 12, tipo: "Biostimulante");
}

Insumo orke() {
  return Insumo(nome: "Orkestra SC", id: 13, tipo: "Fungicida");
}

Insumo alion() {
  return Insumo(nome: "Alion SC500", id: 14, tipo: "Herbicida");
}

Insumo gali() {
  return Insumo(nome: "Galigan", id: 15, tipo: "Herbicida");
}

Insumo gluc() {
  return Insumo(nome: "Glucare", id: 16, tipo: "Herbicida");
}

Insumo glufo() {
  return Insumo(
    nome: "Glufosinate Ammonium 200 G/L SL",
    id: 17,
    tipo: "Herbicida",
  );
}

Insumo grasi() {
  return Insumo(nome: "Grasidim", id: 18, tipo: "Herbicida");
}

Insumo tremor() {
  return Insumo(nome: "Tremor", id: 19, tipo: "Herbicida");
}

Insumo zart() {
  return Insumo(nome: "Zartan", id: 20, tipo: "Herbicida");
}

Insumo mely() {
  return Insumo(nome: "Melyra", id: 21, tipo: "Fungicida");
}

Insumo opera() {
  return Insumo(nome: "Opera", id: 22, tipo: "Fungicida");
}

Insumo valp() {
  return Insumo(nome: "Valpura EC", id: 23, tipo: "Fungicida");
}

Insumo curb() {
  return Insumo(nome: "Curbix SC200", id: 24, tipo: "Inseticida");
}

Insumo fast() {
  return Insumo(nome: "Fastac", id: 25, tipo: "Inseticida");
}

Insumo nomo() {
  return Insumo(nome: "Nomolt", id: 26, tipo: "Inseticida");
}

Insumo premi() {
  return Insumo(nome: "Premier Plus SC", id: 27, tipo: "Inseticida");
}

Insumo veran() {
  return Insumo(nome: "Verango Prime SC500", id: 28, tipo: "Nematicida");
}

Insumo supre() {
  return Insumo(nome: "Supreme Mineral N1", id: 29, tipo: "Fertilizante");
}

Insumo refor() {
  return Insumo(nome: "Reforce Ultra", id: 30, tipo: "Fertilizante");
}

Insumo yara() {
  return Insumo(nome: "YaraLiva Nitrabo", id: 31, tipo: "Fertilizante");
}

Insumo blend() {
  return Insumo(nome: "Blend Mg-Zn-B", id: 32, tipo: "Fertilizante");
}

Insumo trans() {
  return Insumo(nome: "Transfer UP", id: 33, tipo: "Fertilizante");
}

Insumo calSuper() {
  return Insumo(nome: "Cal Super", id: 34, tipo: "Fertilizante");
}

Insumo boroSuper() {
  return Insumo(nome: "Boro Super", id: 35, tipo: "Fertilizante");
}

Insumo ferri() {
  return Insumo(nome: "Ferriflo NG", id: 36, tipo: "Fertilizante");
}

Insumo maxiZinc() {
  return Insumo(nome: "Maxi Zinc", id: 37, tipo: "Fertilizante");
}

Insumo pledge() {
  return Insumo(nome: "Pledge", id: 38, tipo: "Herbicida");
}

Insumo poquer() {
  return Insumo(nome: "Poquer", id: 39, tipo: "Herbicida");
}

Insumo roundup() {
  return Insumo(nome: "Roundup Original", id: 40, tipo: "Herbicida");
}

Insumo cropBest() {
  return Insumo(nome: "Crop Best", id: 41, tipo: "Herbicida");
}

Insumo cropExit() {
  return Insumo(nome: "Crop Exit S", id: 42, tipo: "Herbicida");
}

//Spirit e inseticida + fungicida; o campo tipo so aceita um valor
Insumo spirit() {
  return Insumo(nome: "Spirit", id: 43, tipo: "Inseticida e Fungicida");
}
