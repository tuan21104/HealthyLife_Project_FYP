# Macro Tracking Feature - Deployment Checklist

## Pre-Deployment Verification

### ✅ Backend Layer
- [x] Product schema extended with macro fields (carbs, protein, fat, fiber)
- [x] Order schema updated to store macros in items array
- [x] 10 products seeded with realistic macro data
- [x] Redeem endpoint extracts and calculates macros correctly
- [x] Diary entries include all 4 macros (not just kcal)
- [x] Email notifications include macro breakdown
- [x] Database migrations applied

### ✅ Frontend Layer
- [x] Flutter build successful (no syntax errors)
- [x] shop_screen.dart: Macro display + bottom sheet implemented
- [x] food_detail_screen.dart: Fully localized
- [x] All hardcoded strings replaced with i18n keys
- [x] 4-tile macro display UI working
- [x] Bottom sheet modal working
- [x] CachedNetworkImage for product images

### ✅ Localization
- [x] en.json updated with new diary keys
- [x] vi.json updated with new diary keys
- [x] All UI labels using .tr() method
- [x] Easy Localization package integrated

### ✅ Testing
- [x] Syntax validation passed (get_errors)
- [x] Web build successful
- [x] Seed script runs without errors
- [x] Product data seeded to database

---

## Deployment Steps

### 1. Backend Deployment

```bash
# Verify environment
cd server
cat .env  # Check MONGODB_URI is set

# Run migrations (if any)
# Already applied to Product.js, Order.js

# Seed database
node seed.js
# Expected output: ✅ NẠP DỮ LIỆU THÀNH CÔNG!

# Verify products
node -e "
  require('dotenv').config();
  const mongoose = require('mongoose');
  const Product = require('./models/Product');
  
  mongoose.connect(process.env.MONGODB_URI).then(() => {
    Product.countDocuments().then(count => {
      console.log('Total products:', count);
      process.exit(0);
    });
  });
"

# Start server
npm start
```

### 2. Frontend Deployment

```bash
# Navigate to client
cd client

# Verify Flutter environment
flutter doctor

# Build for target platform
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web
flutter build windows    # Windows
flutter build macos      # macOS
flutter build linux      # Linux

# Or test on device
flutter run
```

### 3. Verification

#### Shop Display Test
```
1. App loads
2. Navigate to Shop tab
3. Verify 10 products display
4. Check each product has macro summary: "X kcal · Xg carb · Xg protein · Xg fat"
5. Tap product → bottom sheet opens
6. Verify 4-tile macro display shows correct values
7. Quantity selector works
8. Add to cart button works
```

#### Redemption Test
```
1. Add food item to cart
2. Proceed to checkout
3. Select meal (breakfast/lunch/snack/dinner)
4. Complete payment with bill image
5. Server processes redemption
6. Check server logs for macro calculation:
   - Verify: productMacros = product.macros × quantity
   - Verify: diary entry includes carb, protein, fat fields
```

#### Diary Verification Test
```
1. Open Diary tab
2. Find today's meal entries from shop redemption
3. Verify meal displays:
   - Meal name ✓
   - Kcal value ✓
   - Carbs (if food) ✓
   - Protein (if food) ✓
   - Fat (if food) ✓
   - Fiber (if food) ✓
   - Timestamp ✓
```

#### Localization Test
```
1. Change app language to Vietnamese
2. Go to Shop → verify labels in Vietnamese
3. Open Product detail bottom sheet → macro labels in Vietnamese
4. Go to Diary → verify all labels in Vietnamese
5. Add food item → verify all UI elements in Vietnamese
6. Change to English → verify all labels in English
```

---

## Rollback Plan (If Needed)

### Backend Rollback
```bash
# If schema migration causes issues:
# 1. Stop server
# 2. Restore backup of MongoDB
# 3. Revert Product.js and Order.js to previous version
# 4. Restart server

# If seed data has errors:
# 1. Clear products collection: db.products.deleteMany({})
# 2. Fix seed.js
# 3. Re-run seed script
```

### Frontend Rollback
```bash
# If UI changes cause crashes:
# 1. Revert shop_screen.dart changes
# 2. Revert food_detail_screen.dart changes
# 3. Rebuild Flutter app
# 4. Redeploy

# Git commands:
git checkout HEAD -- client/lib/shop_screen.dart
git checkout HEAD -- client/lib/food_detail_screen.dart
flutter clean && flutter pub get && flutter build <platform>
```

---

## Production Monitoring

### Metrics to Track

1. **Macro Calculation Accuracy**
   - Verify: product.macros × quantity = diary entry macros
   - Sample orders and cross-check values
   - Monitor for off-by-one errors

2. **Seed Data Validation**
   - Count total products: should be 10
   - Food items: 6 with non-zero macros
   - Equipment items: 4 with zero macros
   - All images loading correctly

3. **Order Processing**
   - Time to calculate macros: should be <100ms
   - Diary entry creation: should be immediate
   - Email delivery: should include macro breakdown

4. **User Experience**
   - Bottom sheet loads quickly
   - Macro values display correctly
   - No UI crashes when adding items
   - Dairy shows complete macro data

### Server Logs to Monitor

```javascript
// Look for these in logs:
"Macro calculation: productCarbs = X"
"Diary entry created with macros: {kcal: X, carb: X, protein: X, fat: X}"
"Order saved with items array containing macros"
```

### Database Checks

```javascript
// Verify product macro data:
db.products.find({category: "food"}).forEach(p => {
  if (!p.carbs || !p.protein || !p.fat) {
    console.log("WARNING: Incomplete macros for", p.name);
  }
});

// Verify diary entries have macros:
db.diaries.find({"meals.carb": {$exists: true}}).count()
// Should return entries with macro data

// Verify orders stored macros:
db.orders.find({"items.carb": {$exists: true}}).count()
// Should show orders with complete macro snapshot
```

---

## Feature Flags (Optional)

If gradual rollout is desired, implement feature flag:

```javascript
// server/.env
ENABLE_MACRO_TRACKING=true

// shop.js
if (process.env.ENABLE_MACRO_TRACKING === 'true') {
  // Calculate and store macros
  const productMacros = {
    carbs: (product.carbs || 0) * quantity,
    protein: (product.protein || 0) * quantity,
    fat: (product.fat || 0) * quantity,
    fiber: (product.fiber || 0) * quantity,
  };
  // ... store in diary
} else {
  // Fallback: only store kcal
  // ... original behavior
}
```

---

## Success Criteria

**Feature is ready for production when:**

✅ All 10 products display with correct macro data  
✅ Bottom sheet UI loads without errors  
✅ Macro values persist in diary after redemption  
✅ Server logs show successful macro calculations  
✅ Both EN and VI translations work  
✅ No crashes in shop or diary flows  
✅ Performance acceptable (< 2s for operations)  
✅ User can see macro breakdown in diary  

---

## Contact & Support

### If Issues Arise

1. **Macro values incorrect in diary**
   - Check: Product.js has correct macro values
   - Check: Redeem endpoint calculation (line 222-224 in shop.js)
   - Check: Diary entry push includes all macro fields

2. **Bottom sheet not showing**
   - Check: ModalEffects import in shop_screen.dart
   - Check: _showProductDetails method implemented
   - Check: CachedNetworkImage package installed

3. **Translations not working**
   - Check: easy_localization package installed
   - Check: en.json and vi.json have matching keys
   - Check: .tr() method called on all string literals

4. **Seed data not populating**
   - Check: .env file has MONGODB_URI
   - Check: MongoDB connection working
   - Check: seed.js file has all 10 products defined

---

## Post-Deployment Walkthrough

1. Open HealthyLife app
2. Log in or sign up
3. Go to Shop tab
4. See 10 products with macro summaries
5. Tap a product → bottom sheet with 4-tile macros
6. Add to cart → add multiple items
7. Go to checkout → select meal time
8. Complete order with bill image
9. Open Diary tab → see new entry with all 4 macros
10. Change to Vietnamese → all UI labels in Vietnamese
11. Success! ✅

