/// Who is using the app.
///
/// The only thing this changes is whether the "could not pray today" option
/// exists: a woman has days she is not meant to pray, and the app should not
/// count those against her.
enum Gender {
  male(id: 'male', arabicName: 'راجل'),
  female(id: 'female', arabicName: 'ست');

  const Gender({required this.id, required this.arabicName});

  final String id;
  final String arabicName;

  /// Whether days can be marked as ones the user could not pray on.
  bool get canExcuseDays => this == Gender.female;

  static Gender fromId(String? id) {
    for (final gender in Gender.values) {
      if (gender.id == id) return gender;
    }
    return Gender.male;
  }
}
