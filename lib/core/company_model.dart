const kSectors = [
  'Agronegócio',
  'Alimentação e Bebidas',
  'Comércio',
  'Construção Civil',
  'Educação',
  'Energia',
  'Indústria',
  'Imobiliário',
  'Mineração',
  'Saúde',
  'Serviços Financeiros',
  'Tecnologia',
  'Telecomunicações',
  'Transporte e Logística',
  'Varejo',
  'Outros',
];

class CompanyModel {
  final String id;
  final String name;
  final String cnpj;
  final String sector;
  final double lat;
  final double lng;
  final int riskLevel; // 1 = Baixo, 2 = Médio, 3 = Alto
  final double score;
  final double debtValue;

  const CompanyModel({
    required this.id,
    required this.name,
    required this.cnpj,
    required this.sector,
    required this.lat,
    required this.lng,
    required this.riskLevel,
    required this.score,
    required this.debtValue,
  });

  String get riskLabel {
    switch (riskLevel) {
      case 1:
        return 'Baixo';
      case 2:
        return 'Médio';
      case 3:
        return 'Alto';
      default:
        return 'Desconhecido';
    }
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'cnpj': cnpj,
        'sector': sector,
        'lat': lat,
        'lng': lng,
        'riskLevel': riskLevel,
        'score': score,
        'debtValue': debtValue,
      };

  factory CompanyModel.fromMap(String id, Map<String, dynamic> map) =>
      CompanyModel(
        id: id,
        name: map['name'] as String,
        cnpj: (map['cnpj'] as String?) ?? '',
        sector: map['sector'] as String,
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
        riskLevel: (map['riskLevel'] as num).toInt(),
        score: (map['score'] as num).toDouble(),
        debtValue: (map['debtValue'] as num).toDouble(),
      );

  CompanyModel copyWith({
    String? id,
    String? name,
    String? cnpj,
    String? sector,
    double? lat,
    double? lng,
    int? riskLevel,
    double? score,
    double? debtValue,
  }) =>
      CompanyModel(
        id: id ?? this.id,
        name: name ?? this.name,
        cnpj: cnpj ?? this.cnpj,
        sector: sector ?? this.sector,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        riskLevel: riskLevel ?? this.riskLevel,
        score: score ?? this.score,
        debtValue: debtValue ?? this.debtValue,
      );
}
