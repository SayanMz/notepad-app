/// A highly condensed, orthogonal taxonomy mapping UI Chip Titles to rich semantic descriptions.
/// The rich description is embedded by the ONNX model to capture a wider net of vocabulary,
/// while the short key is displayed in the UI to prevent vector cannibalization.
class SemanticTaxonomy {
  static const Map<String, String> topicDescriptions = {
    'Software & Tech':
        'Notes and documentation about software engineering, programming, app development, computer science, hardware, and coding.',

    'Entertainment':
        'Notes about entertainment, including video games, movies, television shows, anime, streaming, music, and books.',

    'Work & Study':
        'Notes related to work, education, studying, university academics, career planning, job interviews, and office meetings.',

    'Finance & Shopping':
        'Notes about personal finance, money management, budgets, utility bills, investments, shopping lists, and purchases.',

    'Health & Fitness':
        'Notes regarding health, fitness, workouts, gym exercises, strength training, wellness, and medical information.',

    'Food & Cooking':
        'Notes about food, cooking, baking recipes, culinary ingredients, kitchen preparation, meals, and dining.',

    'Travel & Transport':
        'Notes concerning travel itineraries, vacations, tourism, transit, vehicles, flights, commuting, and road trips.',

    'Personal & Social':
        'Personal journal entries, diary thoughts, social events, gatherings, friends, family, and personal memories.',
  };
}
