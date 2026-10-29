// Plain models for the wire format in docs/API_CONTRACT.md (snake_case JSON).

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
double? _dn(Object? v) => (v as num?)?.toDouble();

class Nutrition {
  const Nutrition({this.calories = 0, this.protein = 0, this.carbohydrates = 0, this.fat = 0, this.fiber});

  final double calories, protein, carbohydrates, fat;
  final double? fiber;

  static const zero = Nutrition();

  factory Nutrition.fromJson(Map<String, dynamic> j) => Nutrition(
    calories: _d(j['calories']),
    protein: _d(j['protein']),
    carbohydrates: _d(j['carbohydrates']),
    fat: _d(j['fat']),
    fiber: _dn(j['fiber']),
  );

  Map<String, dynamic> toJson() => {'calories': calories, 'protein': protein, 'carbohydrates': carbohydrates, 'fat': fat, 'fiber': fiber};

  Nutrition operator +(Nutrition o) => Nutrition(
    calories: calories + o.calories,
    protein: protein + o.protein,
    carbohydrates: carbohydrates + o.carbohydrates,
    fat: fat + o.fat,
    fiber: fiber == null && o.fiber == null ? null : (fiber ?? 0) + (o.fiber ?? 0),
  );

  static Nutrition sum(Iterable<Nutrition> all) => all.fold(zero, (a, b) => a + b);

  @override
  bool operator ==(Object other) =>
      other is Nutrition &&
      other.calories == calories &&
      other.protein == protein &&
      other.carbohydrates == carbohydrates &&
      other.fat == fat &&
      other.fiber == fiber;

  @override
  int get hashCode => Object.hash(calories, protein, carbohydrates, fat, fiber);
}

class FoodItem {
  const FoodItem({required this.id, required this.name, this.serving, required this.nutrition, this.confidence});

  final String id, name;
  final String? serving;
  final Nutrition nutrition;
  final double? confidence;

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
    id: j['id'] as String,
    name: j['name'] as String,
    serving: j['serving'] as String?,
    nutrition: Nutrition.fromJson(j['nutrition'] as Map<String, dynamic>),
    confidence: _dn(j['confidence']),
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'serving': serving, 'nutrition': nutrition.toJson(), 'confidence': confidence};
}

List<FoodItem> _items(Object? v) => ((v as List?) ?? const []).map((e) => FoodItem.fromJson(e as Map<String, dynamic>)).toList();

class ScanResult {
  const ScanResult({
    required this.id,
    required this.recognizedName,
    this.confidence,
    required this.items,
    required this.total,
    required this.potentialAllergens,
    this.imageUrl,
  });

  final String id, recognizedName;
  final double? confidence;
  final List<FoodItem> items;
  final Nutrition total;
  final List<String> potentialAllergens;
  final String? imageUrl;

  factory ScanResult.fromJson(Map<String, dynamic> j) => ScanResult(
    id: j['id'] as String,
    recognizedName: j['recognized_name'] as String,
    confidence: _dn(j['confidence']),
    items: _items(j['items']),
    total: Nutrition.fromJson(j['total'] as Map<String, dynamic>),
    potentialAllergens: ((j['potential_allergens'] as List?) ?? const []).cast<String>(),
    imageUrl: j['image_url'] as String?,
  );
}

class Meal {
  const Meal({
    required this.id,
    required this.name,
    required this.mealType,
    required this.loggedAt,
    required this.localDate,
    required this.nutrition,
    this.items = const [],
    this.notes,
    this.wasUserCorrected = false,
    this.imageUrl,
    this.scanId,
  });

  final String id, name, mealType, localDate;
  final DateTime loggedAt;
  final Nutrition nutrition;
  final List<FoodItem> items;
  final String? notes, imageUrl, scanId;
  final bool wasUserCorrected;

  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
    id: j['id'] as String,
    name: j['name'] as String,
    mealType: j['meal_type'] as String,
    loggedAt: DateTime.parse(j['logged_at'] as String),
    localDate: j['local_date'] as String,
    nutrition: Nutrition.fromJson(j['nutrition'] as Map<String, dynamic>),
    items: _items(j['items']),
    notes: j['notes'] as String?,
    wasUserCorrected: j['was_user_corrected'] as bool? ?? false,
    imageUrl: j['image_url'] as String?,
    scanId: j['scan_id'] as String?,
  );

  /// Body for PUT /v1/meals/{id}.
  Map<String, dynamic> toJson() => {
    'name': name,
    'meal_type': mealType,
    'logged_at': loggedAt.toUtc().toIso8601String(),
    'local_date': localDate,
    'nutrition': nutrition.toJson(),
    'items': items.map((i) => i.toJson()).toList(),
    'notes': notes,
    'was_user_corrected': wasUserCorrected,
    'scan_id': scanId,
  };
}

class Goals {
  const Goals({
    this.mode = 'maintenance',
    this.calorieTarget = 2200,
    this.proteinTarget = 140,
    this.carbohydrateTarget = 220,
    this.fatTarget = 70,
  });

  final String mode;
  final double calorieTarget, proteinTarget, carbohydrateTarget, fatTarget;

  factory Goals.fromJson(Map<String, dynamic> j) => Goals(
    mode: j['mode'] as String? ?? 'maintenance',
    calorieTarget: _d(j['calorie_target']),
    proteinTarget: _d(j['protein_target']),
    carbohydrateTarget: _d(j['carbohydrate_target']),
    fatTarget: _d(j['fat_target']),
  );

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'calorie_target': calorieTarget,
    'protein_target': proteinTarget,
    'carbohydrate_target': carbohydrateTarget,
    'fat_target': fatTarget,
  };

  Goals copyWith({String? mode, double? calorieTarget, double? proteinTarget, double? carbohydrateTarget, double? fatTarget}) => Goals(
    mode: mode ?? this.mode,
    calorieTarget: calorieTarget ?? this.calorieTarget,
    proteinTarget: proteinTarget ?? this.proteinTarget,
    carbohydrateTarget: carbohydrateTarget ?? this.carbohydrateTarget,
    fatTarget: fatTarget ?? this.fatTarget,
  );
}

class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.username,
    this.bio = '',
    this.dietaryRestrictions = const [],
    this.dietaryNotes = '',
    this.privacy = const {},
    this.onboardingCompleted = false,
  });

  final String id, email, displayName, username, bio, dietaryNotes;
  final List<String> dietaryRestrictions;

  /// profile_public, nutrition_visible, workouts_visible, streak_sharing.
  final Map<String, bool> privacy;
  final bool onboardingCompleted;

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] as String,
    email: j['email'] as String,
    displayName: j['display_name'] as String,
    username: j['username'] as String,
    bio: j['bio'] as String? ?? '',
    dietaryRestrictions: ((j['dietary_restrictions'] as List?) ?? const []).cast<String>(),
    dietaryNotes: j['dietary_notes'] as String? ?? '',
    privacy: ((j['privacy'] as Map?) ?? const {}).cast<String, bool>(),
    onboardingCompleted: j['onboarding_completed'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'username': username,
    'bio': bio,
    'dietary_restrictions': dietaryRestrictions,
    'dietary_notes': dietaryNotes,
    'privacy': privacy,
    'onboarding_completed': onboardingCompleted,
  };
}

class Summary {
  const Summary({
    required this.date,
    required this.totals,
    required this.goals,
    required this.meals,
    required this.workoutLogged,
    required this.streakDays,
  });

  final String date;
  final Nutrition totals;
  final Goals goals;
  final List<Meal> meals;
  final bool workoutLogged;
  final int streakDays;

  factory Summary.fromJson(Map<String, dynamic> j) => Summary(
    date: j['date'] as String,
    totals: Nutrition.fromJson(j['totals'] as Map<String, dynamic>),
    goals: Goals.fromJson(j['goals'] as Map<String, dynamic>),
    meals: ((j['meals'] as List?) ?? const []).map((e) => Meal.fromJson(e as Map<String, dynamic>)).toList(),
    workoutLogged: j['workout_logged'] as bool? ?? false,
    streakDays: (j['streak_days'] as num?)?.toInt() ?? 0,
  );
}

class DailyStat {
  const DailyStat({required this.date, required this.nutrition, required this.mealCount, required this.workoutCount});

  final String date;
  final Nutrition nutrition;
  final int mealCount, workoutCount;

  factory DailyStat.fromJson(Map<String, dynamic> j) => DailyStat(
    date: j['date'] as String,
    nutrition: Nutrition.fromJson(j),
    mealCount: (j['meal_count'] as num?)?.toInt() ?? 0,
    workoutCount: (j['workout_count'] as num?)?.toInt() ?? 0,
  );
}

/// Only a streak and "logged today" are ever shared; both are null when the member turned sharing off.
class CircleMember {
  const CircleMember({required this.userId, required this.displayName, this.streakDays, this.loggedToday, required this.sharing});

  final String userId, displayName;
  final int? streakDays;
  final bool? loggedToday;
  final bool sharing;

  factory CircleMember.fromJson(Map<String, dynamic> j) => CircleMember(
    userId: j['user_id'] as String,
    displayName: j['display_name'] as String,
    streakDays: (j['current_streak_days'] as num?)?.toInt(),
    loggedToday: j['logged_today'] as bool?,
    sharing: j['sharing'] as bool? ?? false,
  );
}

class Circle {
  const Circle({required this.id, required this.name, required this.inviteCode, required this.members});

  final String id, name, inviteCode;

  /// Sorted by the server: logged today first, then by streak.
  final List<CircleMember> members;

  factory Circle.fromJson(Map<String, dynamic> j) => Circle(
    id: j['id'] as String,
    name: j['name'] as String,
    inviteCode: j['invite_code'] as String,
    members: ((j['members'] as List?) ?? const []).map((e) => CircleMember.fromJson(e as Map<String, dynamic>)).toList(),
  );
}
