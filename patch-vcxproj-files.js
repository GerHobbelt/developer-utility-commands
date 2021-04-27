//
// patch .vcxproj Visual Studio projeect files to have the proper in-house seettings everywhere. 
// 
// This script can also be uses as a *postprocessor* after you've generated Visual Studio project files using tools like CMake. 
// 
// Sample execution:
// 
//      node /z/tools/patch-vcxproj-files.js $( find . -iname '*.vc*proj' )
//      

const fs = require('fs');
const path = require('path');

const DEBUG = 0;


// each line in here must end up looking like this.
const master_lines_for_replacement = `
	<WindowsTargetPlatformVersion>10.0</WindowsTargetPlatformVersion>
    <PlatformToolset>v142</PlatformToolset>
    <OutDir>$(SolutionDir)$(Configuration)-$(PlatformShortname)\\</OutDir>
    <IntDir>$(SolutionDir)$(Configuration)-$(PlatformShortname)\\$(ProjectName)\\</IntDir>

    <BrowseInformation>false</BrowseInformation>
`;
const extra_master_lines_for_replacement = `
	<CharacterSet>Unicode</CharacterSet>

    <DisableLanguageExtensions>false</DisableLanguageExtensions>
	<LanguageStandard>stdcpp17</LanguageStandard>
	<LanguageStandard_C>stdc17</LanguageStandard_C>

	<FunctionLevelLinking>true</FunctionLevelLinking>
	<StringPooling>true</StringPooling>

    <MakeCFG>$(PlatformShortname)\\$(Configuration)</MakeCFG>
`;

const mandatory_lines = [
	{
		section: '<PropertyGroup Label="Globals">',
		line_key: 'WindowsTargetPlatformVersion',
	},
	{
		section: '<PropertyGroup Label="Configuration">',
		line_key: 'PlatformToolset',
	},
];
const mandatory_lines_to_delete = [
	{
		section: '<ItemDefinitionGroup>',
		subsection: '<BuildLog>',
		line_key: 'Path',
	},
	{
		section: '<ItemDefinitionGroup>',
		line_key: 'BuildLog',
	},
	{
		section: '<Bscmake>',
		line_key: 'OutputFile',
	},
];


const extra_mandatory_lines = [
	{
		section: '<ItemDefinitionGroup>',
		subsection: '<ClCompile>',
		line_key: [ 
			'LanguageStandard',
			'LanguageStandard_C',
			'FunctionLevelLinking',
			'StringPooling',
		],
	},
];
const extra_mandatory_lines_to_delete = [
	/*  not every project file has a common section for this, so we keep the duplication in there...
	{
		section: "<ItemDefinitionGroup Condition=",
		subsection: '<ClCompile>',
		line_key: [ 
			'LanguageStandard',
			'LanguageStandard_C',
			'FunctionLevelLinking',
			'StringPooling',
		],
	},
	*/
];

function depack_master_lines(lines) {
	const arr = lines.trim().split('\n').map((l) => l.trim()).filter((l) => l.trim().length > 0);
	if (DEBUG >= 1) console.error('master lines array:', arr);
	const ml = arr.map((l) => {
		let m = /<([A-Za-z0-9_]+)>/.exec(l);
		return {
			key: m[1],
			line: l
		};
	});
	if (DEBUG >= 1) console.error('master lines array (PROCESSED:', ml);
	return ml;
}

function munch(p, also_process_extras) {
	let src = fs.readFileSync(p, 'utf8');
	if (DEBUG >= 1) console.error(src);

	const ml1 = depack_master_lines(master_lines_for_replacement);
	if (DEBUG >= 1) console.error('ml1:', ml1);
	let ml_lookup = {};
	for (const line of ml1) {
		let re = new RegExp(`<${line.key}[ >][^]*?</${line.key}>`, 'g');
		src = src.replace(re, line.line);

		ml_lookup[line.key] = line;
	}

	const ml2 = depack_master_lines(extra_master_lines_for_replacement);
	if (DEBUG >= 1) console.error('ml2:', ml2);
	if (also_process_extras) {
		for (const line of ml2) {
			let re = new RegExp(`<${line.key}[ >][^]*?</${line.key}>`, 'g');
			src = src.replace(re, line.line);

			ml_lookup[line.key] = line;
		}
	}


	for (const el of mandatory_lines) {
		let section = el.section;
		let m = /<([A-Za-z0-9_]+)[ >]/.exec(section);
		if (DEBUG >= 1) console.error('mandatory_lines: ', { section })
		let section_key = m[1];
		let re = new RegExp(`(${section})([^]*?)(</${section_key}>)`, 'g');

		let replace_f = (re, line_key, src) => {
			src = src.replace(re, (m, p1, p2, p3) => {
				if (DEBUG >= 1) console.error("process match chunk: ", m);
				let inject_line = ml_lookup[line_key];
				if (!p2.includes(line_key)) {
					// line has not yet been replaced in master replace section further above. 
					// Inject the line at the end of the chunk instead.
					if (DEBUG >= 1) console.error("inject mandatory line: ", inject_line.line);
					p2 = p2.trimEnd() + '\n    ' + inject_line.line + '\n';
				}
				else {
					let replace_re = new RegExp(`<${line_key}[ >][^]*?</${line_key}>`, 'g');
					p2 = p2.replace(replace_re, inject_line.line);
				} 

				return p1 + p2 + p3;
			});
			return src;
		};

		if (el.subsection) {
			let subsection = el.subsection;
			m = /<([A-Za-z0-9_]+)[ >]/.exec(subsection);
			if (DEBUG >= 1) console.error('mandatory_lines: SUBSECTION:', { subsection })
			let subsection_key = m[1];
			let subre = new RegExp(`(${subsection})([^]*?)(</${subsection_key}>)`, 'g');

			src = src.replace(re, (m, p1, p2, p3) => {
				if (DEBUG >= 1) console.error('processing subsection:', m);
				p2 = replace_f(subre, el.line_key, p2);

				return p1 + p2 + p3;
			});
		}
		else {
			src = replace_f(re, el.line_key, src);
		}
	} 

	if (also_process_extras) {
		for (const el of extra_mandatory_lines) {
			let section = el.section;
			let m = /<([A-Za-z0-9_]+)[ >]/.exec(section);
			if (DEBUG >= 1) console.error('extra_mandatory_lines: ', { section })
			let section_key = m[1];
			let re = new RegExp(`(${section})([^]*?)(</${section_key}>)`, 'g');

			let replace_f = (re, line_key, src) => {
				src = src.replace(re, (m, p1, p2, p3) => {
					if (DEBUG >= 1) console.error("process match chunk: ", m);
					if (Array.isArray(line_key)) {
						for (const key of line_key) {
							let inject_line = ml_lookup[key];
							if (!p2.includes(key)) {
								// line has not yet been replaced in master replace section further above. 
								// Inject the line at the end of the chunk instead.
								if (DEBUG >= 1) console.error("inject mandatory line: ", { key, l: inject_line ? inject_line.line : '???' } );
								p2 = p2.trimEnd() + '\n    ' + inject_line.line + '\n';
							}
							else {
								let replace_re = new RegExp(`<${key}[ >][^]*?</${key}>`, 'g');
								p2 = p2.replace(replace_re, inject_line.line);
							} 
						}
					} else {
						let inject_line = ml_lookup[line_key];
						if (!p2.includes(line_key)) {
							// line has not yet been replaced in master replace section further above. 
							// Inject the line at the end of the chunk instead.
							if (DEBUG >= 1) console.error("inject mandatory line: ", { line_key, l: inject_line ? inject_line.line : '???' } );
							p2 = p2.trimEnd() + '\n    ' + inject_line.line + '\n';
						}
						else {
							let replace_re = new RegExp(`<${line_key}[ >][^]*?</${line_key}>`, 'g');
							p2 = p2.replace(replace_re, inject_line.line);
						} 
					}
					return p1 + p2 + p3;
				});
				return src;
			};

			if (el.subsection) {
				let subsection = el.subsection;
				m = /<([A-Za-z0-9_]+)[ >]/.exec(subsection);
				if (DEBUG >= 1) console.error('mandatory_lines: SUBSECTION:', { subsection })
				let subsection_key = m[1];
				let subre = new RegExp(`(${subsection})([^]*?)(</${subsection_key}>)`, 'g');

				src = src.replace(re, (m, p1, p2, p3) => {
					if (DEBUG >= 1) console.error('processing subsection:', m);
					p2 = replace_f(subre, el.line_key, p2);

					return p1 + p2 + p3;
				});
			}
			else {
				src = replace_f(re, el.line_key, src);
			}
		} 
	}







	for (const el of mandatory_lines_to_delete) {
		let section = el.section;
		let m = /<([A-Za-z0-9_]+)[ >]/.exec(section);
		if (DEBUG >= 1) console.error('mandatory_lines_to_delete: ', { section })
		let section_key = m[1];
		let re = new RegExp(`(${section})([^]*?)(</${section_key}>)`, 'g');

		let replace_f = (re, line_key, src) => {
			src = src.replace(re, (m, p1, p2, p3) => {
				if (DEBUG >= 1) console.error("process match chunk to delete: ", m);
				if (Array.isArray(line_key)) {
					for (const key of line_key) {
						let del_re = new RegExp(`<${key}[ >]([^]*?)</${key}>`, 'g');
						p2 = p2.replace(del_re, '');
					}
				} else {
					let del_re = new RegExp(`<${line_key}[ >]([^]*?)</${line_key}>`, 'g');
					p2 = p2.replace(del_re, '');
				}
				return p1 + p2 + p3;
			});
			return src;
		};

		if (el.subsection) {
			let subsection = el.subsection;
			m = /<([A-Za-z0-9_]+)[ >]/.exec(subsection);
			if (DEBUG >= 1) console.error('mandatory_lines_to_delete: SUBSECTION:', { subsection })
			let subsection_key = m[1];
			let subre = new RegExp(`(${subsection})([^]*?)(</${subsection_key}>)`, 'g');

			src = src.replace(re, (m, p1, p2, p3) => {
				if (DEBUG >= 1) console.error('processing subsection:', m);
				p2 = replace_f(subre, el.line_key, p2);

				return p1 + p2 + p3;
			});
		}
		else {
			src = replace_f(re, el.line_key, src);
		}
	} 

	if (also_process_extras) {
		for (const el of extra_mandatory_lines_to_delete) {
			let section = el.section;
			let m = /<([A-Za-z0-9_]+)[ >]/.exec(section);
			if (DEBUG >= 1) console.error('extra_mandatory_lines_to_delete: ', { section })
			let section_key = m[1];
			let re = new RegExp(`(${section})([^]*?)(</${section_key}>)`, 'g');

			let replace_f = (re, line_key, src) => {
				src = src.replace(re, (m, p1, p2, p3) => {
					if (DEBUG >= 1) console.error("process match chunk to delete: ", m);
					if (Array.isArray(line_key)) {
						for (const key of line_key) {
							let del_re = new RegExp(`<${key}[ >]([^]*?)</${key}>`, 'g');
							p2 = p2.replace(del_re, '');
						}
					} else {
						let del_re = new RegExp(`<${line_key}[ >]([^]*?)</${line_key}>`, 'g');
						p2 = p2.replace(del_re, '');
					}
					return p1 + p2 + p3;
				});
				return src;
			};

			if (el.subsection) {
				let subsection = el.subsection;
				m = /<([A-Za-z0-9_]+)[ >]/.exec(subsection);
				if (DEBUG >= 1) console.error('mandatory_lines_to_delete: SUBSECTION:', { subsection })
				let subsection_key = m[1];
				let subre = new RegExp(`(${subsection})([^]*?)(</${subsection_key}>)`, 'g');

				src = src.replace(re, (m, p1, p2, p3) => {
					if (DEBUG >= 1) console.error('processing subsection:', m);
					p2 = replace_f(subre, el.line_key, p2);

					return p1 + p2 + p3;
				});
			}
			else {
				src = replace_f(re, el.line_key, src);
			}
		} 
	}


	//if (DEBUG >= 1) console.error(src);


	fs.writeFileSync(p, src, 'utf8');
}











if (DEBUG >= 1) console.error(process.argv, process.argc);

if (process.argc <= 2) {
	console.error('tool <list of *.vcxproj file paths to process>');
	process.exit(1);
}

for (const p of process.argv.slice(2)) {
	console.error('path to process: ', p);
	munch(p, true);
}
