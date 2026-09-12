/// A highly condensed, orthogonal taxonomy mapping UI Chip Titles to rich semantic descriptions.
/// The rich description is embedded by the ONNX model to capture a wider net of vocabulary,
/// while the short key is displayed in the UI to prevent vector cannibalization.
class SemanticTaxonomy {
  static const Map<String, String> topicDescriptions = {
    'Software & Tech':
        'Software engineering, source code, app development, IT systems, tech hardware, and programming.',

    'Entertainment':
        'Video games, movies, television shows, anime, streaming, music, cinema, novels, and books.',

    'Work & Study':
        'Work tasks, business strategy, project planning, meetings, roadmaps, sprint reviews, school homework, studying exams, mathematics, academics, and education.',

    'Finance & Shopping':
        'Personal finance, money management, budgets, utility bills, taxes, legal documents, investments, shopping lists, and purchases.',

    'Health & Fitness':
        'Health, fitness, workouts, gym exercises, strength training, wellness, nutrition, and medical information.',

    'Food & Cooking':
        'Food recipes, culinary ingredients, kitchen preparation, baking, cooking, culinary dishes, and cooking methods.',

    'Travel & Transport':
        'Travel itineraries, vacations, tourism, transit, vehicles, flights, commuting, and road trips.',

    'Personal & Social':
        'Personal journal entries, diary reflections, feelings, nostalgia, friends, family, pets, hobbies, household chores, social gatherings, hangouts, and life memories.',
  };
}
