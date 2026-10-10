// Offline guidance. Works with no internet, in English and Hindi.
// General farming practice only: no pesticide names or doses.

class OfflineGuide {
  final String summary;
  final List<String> steps;
  final String callExpert;
  const OfflineGuide(this.summary, this.steps, this.callExpert);
}

const Map<String, OfflineGuide> _en = {
  'healthy': OfflineGuide(
    'The leaf looks healthy.',
    [
      'Keep checking the leaves every few days.',
      'Water at the base of the plant, not on the leaves.',
      'Keep the field clean and remove weeds.',
    ],
    'Call an agriculture officer if spots or yellowing appear.',
  ),
  'early': OfflineGuide(
    'This may be early blight, a fungus that makes brown spots with rings.',
    [
      'Remove the worst leaves and keep them away from the field.',
      'Avoid wetting the leaves. Water in the morning at the base.',
      'Keep space between plants so air can pass.',
    ],
    'Call your agriculture officer if the spots keep spreading after 3 to 4 days.',
  ),
  'late': OfflineGuide(
    'This may be late blight. It spreads fast in cool, wet weather.',
    [
      'Remove badly affected plants or leaves and bury them away from the field.',
      'Do not water in the evening and keep the leaves dry.',
      'Check the nearby plants every day.',
    ],
    'Contact your agriculture officer or KVK today if many plants are affected.',
  ),
  'bacterial': OfflineGuide(
    'This may be bacterial spot, which causes small dark spots on leaves.',
    [
      'Do not touch plants or work in the field when the leaves are wet.',
      'Remove badly spotted leaves and keep your tools clean.',
      'Use clean seed and change the crop next season.',
    ],
    'Ask your agriculture officer to confirm before any treatment.',
  ),
  'mold': OfflineGuide(
    'This may be leaf mold, common when the air is humid and still.',
    [
      'Open up the plants so air can move between them.',
      'Keep the leaves dry and let fresh air into the field or shade net.',
      'Remove badly affected leaves.',
    ],
    'Call an expert if the mold keeps spreading.',
  ),
  'virus': OfflineGuide(
    'This may be a virus disease. Viruses spread by insects and by touch, and the plant cannot be cured.',
    [
      'Separate or remove the affected plants so the others stay safe.',
      'Control insects like whiteflies and aphids near the plants.',
      'Wash your hands and tools after touching sick plants.',
    ],
    'Ask your agriculture officer to confirm, because viruses are hard to tell by eye.',
  ),
  'spot': OfflineGuide(
    'This may be a leaf spot disease caused by a fungus or bacteria.',
    [
      'Remove the most spotted leaves and keep the field clean.',
      'Water at the base in the morning, not over the leaves.',
      'Do not leave fallen sick leaves on the ground.',
    ],
    'Call your agriculture officer if new leaves also show spots.',
  ),
  'unsure': OfflineGuide(
    'The photo is not clear enough to name a problem.',
    [
      'Retake the photo in daylight: one leaf, close-up, plain background.',
      'Check the plant again in 2 days.',
      'Remove clearly dead leaves and keep the field clean.',
    ],
    'Show the plant to your agriculture officer if it keeps getting worse.',
  ),
};

const Map<String, OfflineGuide> _hi = {
  'healthy': OfflineGuide(
    'पत्ती स्वस्थ दिख रही है।',
    [
      'हर कुछ दिन में पत्तियों की जाँच करते रहें।',
      'पानी पौधे की जड़ में दें, पत्तियों पर नहीं।',
      'खेत साफ रखें और खरपतवार निकालते रहें।',
    ],
    'अगर धब्बे या पीलापन दिखे तो कृषि अधिकारी से संपर्क करें।',
  ),
  'early': OfflineGuide(
    'यह अर्ली ब्लाइट हो सकता है। यह एक फफूंद रोग है और भूरे गोल धब्बे बनाता है।',
    [
      'सबसे ज़्यादा खराब पत्तियाँ तोड़कर खेत से दूर रखें।',
      'पत्तियों को गीला न करें। सुबह जड़ के पास पानी दें।',
      'पौधों के बीच जगह रखें ताकि हवा आ-जा सके।',
    ],
    'अगर 3-4 दिन बाद भी धब्बे फैलते रहें तो कृषि अधिकारी से संपर्क करें।',
  ),
  'late': OfflineGuide(
    'यह लेट ब्लाइट हो सकता है। यह ठंडे और नमी वाले मौसम में तेज़ी से फैलता है।',
    [
      'बहुत खराब पौधे या पत्तियाँ निकालकर खेत से दूर गाड़ दें।',
      'शाम को पानी न दें और पत्तियों को सूखा रखें।',
      'आस-पास के पौधों को रोज़ देखें।',
    ],
    'अगर कई पौधे प्रभावित हों तो आज ही कृषि अधिकारी या केवीके से संपर्क करें।',
  ),
  'bacterial': OfflineGuide(
    'यह बैक्टीरियल स्पॉट हो सकता है, जिसमें पत्तियों पर छोटे काले धब्बे बनते हैं।',
    [
      'पत्तियाँ गीली हों तब पौधों को न छुएँ और खेत में काम न करें।',
      'बहुत धब्बेदार पत्तियाँ हटा दें और औज़ार साफ रखें।',
      'साफ बीज इस्तेमाल करें और अगले मौसम में फसल बदलें।',
    ],
    'कोई भी इलाज करने से पहले कृषि अधिकारी से पुष्टि करवाएँ।',
  ),
  'mold': OfflineGuide(
    'यह लीफ मोल्ड हो सकता है। यह नमी वाली और रुकी हुई हवा में आम है।',
    [
      'पौधों के बीच हवा आने-जाने की जगह बनाएँ।',
      'पत्तियों को सूखा रखें और खेत या शेड नेट में ताज़ी हवा आने दें।',
      'बहुत प्रभावित पत्तियाँ हटा दें।',
    ],
    'अगर फफूंद फैलती रहे तो विशेषज्ञ से संपर्क करें।',
  ),
  'virus': OfflineGuide(
    'यह वायरस रोग हो सकता है। वायरस कीड़ों और छूने से फैलता है और पौधा ठीक नहीं होता।',
    [
      'प्रभावित पौधों को अलग करें या हटा दें ताकि बाकी बचे रहें।',
      'पौधों के पास सफेद मक्खी और माहू जैसे कीड़ों को काबू में रखें।',
      'बीमार पौधे छूने के बाद हाथ और औज़ार धो लें।',
    ],
    'वायरस आँख से पहचानना मुश्किल है, इसलिए कृषि अधिकारी से पुष्टि करवाएँ।',
  ),
  'spot': OfflineGuide(
    'यह पत्ती धब्बा रोग हो सकता है, जो फफूंद या बैक्टीरिया से होता है।',
    [
      'सबसे ज़्यादा धब्बेदार पत्तियाँ हटाएँ और खेत साफ रखें।',
      'सुबह जड़ के पास पानी दें, पत्तियों के ऊपर नहीं।',
      'गिरी हुई बीमार पत्तियों को ज़मीन पर न छोड़ें।',
    ],
    'अगर नई पत्तियों पर भी धब्बे दिखें तो कृषि अधिकारी से संपर्क करें।',
  ),
  'unsure': OfflineGuide(
    'फोटो इतनी साफ नहीं है कि समस्या का नाम बताया जा सके।',
    [
      'दिन की रोशनी में दोबारा फोटो लें: एक पत्ती, पास से, सादी पृष्ठभूमि।',
      '2 दिन बाद पौधे को फिर देखें।',
      'साफ सूखी पत्तियाँ हटाएँ और खेत साफ रखें।',
    ],
    'अगर हालत बिगड़ती रहे तो पौधा कृषि अधिकारी को दिखाएँ।',
  ),
};

/// Returns null when the condition is not one we have offline advice for.
OfflineGuide? offlineGuideFor(String condition, String language) {
  final c = condition.toLowerCase();
  String? key;
  if (c.contains('healthy')) {
    key = 'healthy';
  } else if (c.contains('not sure') || c.contains('unknown')) {
    key = 'unsure';
  } else if (c.contains('early blight')) {
    key = 'early';
  } else if (c.contains('late blight')) {
    key = 'late';
  } else if (c.contains('bacterial')) {
    key = 'bacterial';
  } else if (c.contains('mold') || c.contains('mould')) {
    key = 'mold';
  } else if (c.contains('mosaic') || c.contains('virus') || c.contains('curl')) {
    key = 'virus';
  } else if (c.contains('spot') || c.contains('septoria')) {
    key = 'spot';
  }
  if (key == null) return null;
  return (language == 'Hindi' ? _hi : _en)[key];
}
