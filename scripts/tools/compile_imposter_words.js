#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// File paths
const projectRoot = path.resolve(__dirname, '../..');
const charadesPath = path.join(projectRoot, 'data/prompts/charades_prompts.json');
const quickDrawPath = path.join(projectRoot, 'data/prompts/quick_draw_words.json');
const outputPath = path.join(projectRoot, 'data/prompts/imposter_words.json');

console.log('Compiling Imposter word list...\n');

try {
  // Read charades prompts
  console.log(`Reading: ${charadesPath}`);
  const charadesData = JSON.parse(fs.readFileSync(charadesPath, 'utf8'));

  // Flatten all charades prompts from all categories
  const charadesWords = [];
  for (const category in charadesData) {
    if (Array.isArray(charadesData[category])) {
      charadesWords.push(...charadesData[category]);
    }
  }
  console.log(`  Found ${charadesWords.length} words from charades prompts`);

  // Read quick draw words
  console.log(`Reading: ${quickDrawPath}`);
  const quickDrawData = JSON.parse(fs.readFileSync(quickDrawPath, 'utf8'));

  // Flatten all quick draw words from all difficulty levels
  const quickDrawWords = [];
  for (const difficulty in quickDrawData) {
    if (Array.isArray(quickDrawData[difficulty])) {
      quickDrawWords.push(...quickDrawData[difficulty]);
    }
  }
  console.log(`  Found ${quickDrawWords.length} words from quick draw`);

  // Combine and deduplicate
  const allWords = [...charadesWords, ...quickDrawWords];
  const uniqueWords = [...new Set(allWords)];

  // Sort alphabetically (case-insensitive)
  uniqueWords.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));

  console.log(`\nTotal unique words: ${uniqueWords.length}`);
  console.log(`Duplicates removed: ${allWords.length - uniqueWords.length}`);

  // Write output
  console.log(`\nWriting to: ${outputPath}`);
  fs.writeFileSync(outputPath, JSON.stringify(uniqueWords, null, 2) + '\n', 'utf8');

  console.log('\n✓ Compilation complete!');

} catch (error) {
  console.error('\n✗ Error during compilation:');
  console.error(error.message);
  process.exit(1);
}
