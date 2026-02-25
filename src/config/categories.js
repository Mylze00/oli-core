/**
 * Source unique de vérité pour les catégories de produits.
 * Utilisé par le backend, le seller center, et exposé via GET /api/categories.
 */
const CATEGORIES = [
  { key: 'industry', label: 'Industrie', icon: 'factory', image: 'categories/industry.png' },
  { key: 'home', label: 'Maison', icon: 'chair', image: 'categories/home.png' },
  { key: 'vehicles', label: 'Véhicules', icon: 'directions_car', image: 'categories/vehicles.png' },
  { key: 'fashion', label: 'Mode', icon: 'checkroom', image: 'categories/fashion.png' },
  { key: 'electronics', label: 'Électronique', icon: 'phone_android', image: 'categories/electronics.png' },
  { key: 'sports', label: 'Sports', icon: 'sports_soccer', image: 'categories/sports.png' },
  { key: 'beauty', label: 'Beauté', icon: 'face', image: 'categories/beauty.png' },
  { key: 'toys', label: 'Jouets', icon: 'toys', image: 'categories/toys.png' },
  { key: 'health', label: 'Santé', icon: 'medical_services', image: 'categories/health.png' },
  { key: 'construction', label: 'Construction', icon: 'construction', image: 'categories/construction.png' },
  { key: 'tools', label: 'Outils', icon: 'build', image: 'categories/tools.png' },
  { key: 'office', label: 'Bureau', icon: 'desk', image: 'categories/office.png' },
  { key: 'garden', label: 'Jardin', icon: 'grass', image: 'categories/garden.png' },
  { key: 'pets', label: 'Animaux', icon: 'pets', image: 'categories/pets.png' },
  { key: 'baby', label: 'Bébé', icon: 'child_friendly', image: 'categories/baby.png' },
  { key: 'food', label: 'Alimentation', icon: 'restaurant', image: 'categories/food.png' },
  { key: 'security', label: 'Sécurité', icon: 'security', image: 'categories/security.png' },
  { key: 'other', label: 'Autres', icon: 'category', image: 'categories/other.png' },
];

// Map label FR → clé EN (pour migration et validation)
const LABEL_TO_KEY = {};
CATEGORIES.forEach(c => { LABEL_TO_KEY[c.label] = c.key; });

// Set des clés valides
const VALID_KEYS = new Set(CATEGORIES.map(c => c.key));

module.exports = { CATEGORIES, LABEL_TO_KEY, VALID_KEYS };
