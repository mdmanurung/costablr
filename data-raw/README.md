# Bundled Onset of Labor data provenance

The bounded examples in `inst/extdata` derive from the Dryad dataset
“Multiomics modeling of the immunome, transcriptome, microbiome, proteome and
metabolome adaptations during human pregnancy”
(<https://doi.org/10.5061/dryad.stqjq2c7d>), released under CC0. The associated
study is <https://doi.org/10.1126/scitranslmed.abd9898>.

Only the sample identifier, DOS outcome, and the first 100 CyTOF and proteomic
feature columns (in source order) are retained. The six source tables already
encode the study's training and validation split; no new split is generated.
Values are the study-exported processed measurements; the
package applies no additional normalization or imputation.

Run `prepare_ool_data.R` on the six exported Dryad tables to rebuild the
fixtures. The script verifies these source SHA-256 checksums before writing:

- Training CyTOF: `c17d4d2ad44a2a8b1da887a58b0cf190c1f74c23755f0f80c6231945f97f47f6`
- Training proteomics: `5037b8e2ff3c28c4d562bb32e6d04977c1532f73d659bdccaefa18271785dfba`
- Training DOS: `11889faf2d1c3846025f57fa89e3a92f036aeff7162596a4d69f7eccf72695ec`
- Validation CyTOF: `912053964c201c215ce557ab9bc43488a74da3f9c1b2b331f5ec5b85de40ccfd`
- Validation proteomics: `55fb10bd1d2093d8bc593e7d4509fb51389f8882b842db1e8bf8139ff6584c71`
- Validation DOS: `f1bf4ed0dc1f577fb59e44b4a9014bcc4b7516677705c524790cadfc226c8ab6`

The committed output-file SHA-256 checksums are:

- `ool_cytof_train.csv.gz`: `2fffa0d6bdfeea18886e7b6036fb2c57ee6edd21220112c673182c0f44db4b97`
- `ool_cytof_valid.csv.gz`: `e8d1ffd721f9f41994bd98b78cca9431f60ab25ca59e5f2b5fc8577f9b313fa3`
- `ool_dos_train.csv`: `fcdf4f931cbb40ab084da86da5b48f454e43cca945f070e301ee101c438dbe70`
- `ool_dos_valid.csv`: `90223bfdde2233108ea7b046a0c8c9a8228afbcb56005e8a32dc0640472ce530`
- `ool_proteomics_train.csv.gz`: `d391b512f984e4d3c0141e3b53fcaefc82a3b006a59549c09114a25752e34c4c`
- `ool_proteomics_valid.csv.gz`: `8072550a5e0e415bb235e9e705ade8f3033249a3a62fb550af0fb3e256ff8a41`
