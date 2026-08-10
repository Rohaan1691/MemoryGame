class CountryModel {
  String emoji;
  String code;
  String name;
  String fact;

  CountryModel(this.emoji, this.code, this.name, this.fact);

  CountryModel copyWith({String? emoji, String? code, String? name, String? fact}) {
    return CountryModel(
      emoji ?? this.emoji,
      code ?? this.code,
      name ?? this.name,
      fact ?? this.fact,
    );
  }
}