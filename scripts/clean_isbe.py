import pandas as pd 

def combine_excel():
    xls = pd.ExcelFile('cps_school_report.xlsx')
    df_combined = xls.parse('SAT').loc[1424:2061, ['School Name']]

    sheets_and_columns = {
        'ELA Math Science': '# ELA Proficiency',
        'SAT': ['SAT Reading Average Score', 'SAT Math Average Score'],
        'ISA': '# ISA Proficiency Total Student'
    }

    for sheet, columns in sheets_and_columns.items():
        df = xls.parse(sheet)
        if not isinstance(columns, list):
            columns = [columns]
        df_trimmed = df.loc[1424:2061, columns]
        print(df_trimmed.columns)
        df_trimmed.columns = [f'{sheet}_{col}' for col in df_trimmed.columns]
        df_combined = pd.concat([df_combined, df_trimmed], axis=1)
    df_combined.to_csv('data/cps_schools.csv', index=False)