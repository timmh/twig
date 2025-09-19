#!/usr/bin/env python3
"""
Script to enhance labels.csv with common names for species.
Downloads and caches Catalogue of Life data to map scientific names to common names.
"""

import csv
import zipfile
import urllib.request
import urllib.error
import re
import sys
from pathlib import Path

# Increase CSV field size limit
csv.field_size_limit(sys.maxsize)

# Configuration
# Get the directory of the current script
SCRIPT_DIR = Path(__file__).parent
CACHE_DIR = SCRIPT_DIR / 'cache'
COL_DATA_URL = "https://api.checklistbank.org/dataset/311872/export.zip?extended=true&format=ColDP"
COL_CACHE_FILE = CACHE_DIR / 'col_data.zip'
COL_EXTRACTED_DIR = CACHE_DIR / 'col_data'

def ensure_cache_dir():
    """Create cache directory if it doesn't exist."""
    CACHE_DIR.mkdir(exist_ok=True)
    COL_EXTRACTED_DIR.mkdir(exist_ok=True)

def download_col_data():
    """Download Catalogue of Life data if not cached."""
    if COL_CACHE_FILE.exists():
        print(f"Using cached COL data: {COL_CACHE_FILE}")
        return

    print(f"Downloading Catalogue of Life data from {COL_DATA_URL}")
    print("This may take several minutes...")

    try:
        urllib.request.urlretrieve(COL_DATA_URL, COL_CACHE_FILE)
        print(f"Downloaded COL data to {COL_CACHE_FILE}")
    except urllib.error.URLError as e:
        print(f"Error downloading COL data: {e}")
        raise

def extract_col_data():
    """Extract the COL data if not already extracted."""
    # Check if already extracted by looking for key files
    taxa_file = COL_EXTRACTED_DIR / 'NameUsage.tsv'
    vernacular_file = COL_EXTRACTED_DIR / 'VernacularName.tsv'

    if taxa_file.exists() and vernacular_file.exists():
        print(f"Using cached extracted COL data: {COL_EXTRACTED_DIR}")
        return

    print(f"Extracting COL data to {COL_EXTRACTED_DIR}")

    with zipfile.ZipFile(COL_CACHE_FILE, 'r') as zip_ref:
        zip_ref.extractall(COL_EXTRACTED_DIR)

    print("COL data extracted successfully")

def load_bird_species_mapping():
    """Load species and their vernacular names from COL data."""
    taxa_file = COL_EXTRACTED_DIR / 'NameUsage.tsv'
    vernacular_file = COL_EXTRACTED_DIR / 'VernacularName.tsv'

    if not taxa_file.exists() or not vernacular_file.exists():
        print(f"Warning: COL data files not found in {COL_EXTRACTED_DIR}")
        return {}

    print("Loading species from COL data...")

    # First, load all taxa and find birds (class Aves)
    bird_taxa = {}

    with open(taxa_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter='\t')
        for row in reader:
            # Look for class Aves (birds) using the col: prefix
            if row.get('col:class') == 'Aves' and row.get('col:rank') == 'species':
                scientific_name = row.get('col:scientificName', '').strip()
                if scientific_name and ' ' in scientific_name:  # Valid binomial name
                    bird_taxa[row.get('col:ID')] = scientific_name

    print(f"Found {len(bird_taxa)} bird species in COL data")

    # Now load vernacular names for these bird species
    species_mapping = {}

    with open(vernacular_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter='\t')
        for row in reader:
            taxon_id = row.get('col:taxonID')
            if taxon_id in bird_taxa:
                scientific_name = bird_taxa[taxon_id]
                vernacular_name = row.get('col:name', '').strip()
                language = row.get('col:language', '').strip()

                # Prefer English names
                if language.lower() in ['en', 'eng', 'english'] and vernacular_name:
                    if scientific_name not in species_mapping:
                        species_mapping[scientific_name] = vernacular_name
                        print(f"Mapped: {scientific_name} -> {vernacular_name}")

    print(f"Loaded {len(species_mapping)} common name mappings")
    return species_mapping

def is_scientific_name(label):
    """
    Check if a label appears to be a scientific name (binomial nomenclature).
    """
    # Skip labels with underscores and parentheses (non-species)
    if '_' in label or '(' in label:
        return False

    # Scientific names should have exactly 2 words
    parts = label.strip().split()
    if len(parts) != 2:
        return False

    # First word (genus) should be capitalized, second (species) lowercase
    genus, species = parts
    if not (genus[0].isupper() and species[0].islower()):
        return False

    # Should contain only alphabetic characters (no numbers or special chars)
    if not (genus.isalpha() and species.isalpha()):
        return False

    return True

def format_non_species_label(label):
    """
    Format non-species labels by replacing underscores with spaces.
    """
    # Replace underscores with spaces
    formatted = label.replace('_', ' ')

    # Remove parenthetical content for cleaner display
    formatted = re.sub(r'\s*\([^)]*\)', '', formatted)

    return formatted.strip()

def process_labels():
    """
    Process the labels.csv file and create an enhanced version with common names.
    """

    input_file = SCRIPT_DIR / 'weights/assets/labels.csv'
    output_file = SCRIPT_DIR / 'weights/assets/enhanced_labels.csv'

    # Setup cache and download data
    ensure_cache_dir()
    download_col_data()
    extract_col_data()

    # Load species mapping from COL data
    species_mapping = load_bird_species_mapping()

    enhanced_labels = []
    processed_count = 0
    species_count = 0
    mapped_count = 0

    print(f"\nReading labels from {input_file}")

    with open(input_file, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        for row in reader:
            if not row:
                continue

            original_label = row[0].strip()
            processed_count += 1

            if processed_count % 1000 == 0:
                print(f"Processed {processed_count} labels...")

            # Check if this looks like a scientific name
            if is_scientific_name(original_label):
                species_count += 1

                # Try to get common name from COL data
                common_name = species_mapping.get(original_label)

                if common_name:
                    mapped_count += 1

                enhanced_labels.append({
                    'original_label': original_label,
                    'common_name': common_name or '',
                    'display_name': common_name or original_label
                })
            else:
                # Non-species label - format it nicely
                formatted_name = format_non_species_label(original_label)
                enhanced_labels.append({
                    'original_label': original_label,
                    'common_name': '',
                    'display_name': formatted_name
                })

    print(f"\nProcessing complete!")
    print(f"Total labels processed: {processed_count}")
    print(f"Scientific names found: {species_count}")
    print(f"Common names mapped: {mapped_count}")

    # Write enhanced labels to CSV
    print(f"\nWriting enhanced labels to {output_file}")

    with open(output_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)

        # Write header
        writer.writerow(['original_label', 'common_name', 'display_name'])

        # Write data
        for label_data in enhanced_labels:
            writer.writerow([
                label_data['original_label'],
                label_data['common_name'],
                label_data['display_name']
            ])

    print(f"Enhanced labels saved to {output_file}")

    # Show some examples
    print("\nSample mappings:")
    sample_count = 0
    for label_data in enhanced_labels:
        if label_data['common_name'] and sample_count < 10:
            print(f"  {label_data['original_label']} -> {label_data['common_name']}")
            sample_count += 1
        elif '_' in label_data['original_label'] and sample_count < 15:
            print(f"  {label_data['original_label']} -> {label_data['display_name']} (formatted)")
            sample_count += 1

        if sample_count >= 15:
            break

if __name__ == '__main__':
    try:
        process_labels()
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()