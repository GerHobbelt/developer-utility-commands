#! /bin/bash
#
# Generate a git-based CONTRIBUTORS.md list/document from the repo data.
# 
# Extra: when the .CONTRIBUTORS.supplement file exists, do add those entries as well!
# The .CONTRIBUTORS.supplement file can use the same format as the regular `git log` output:
# after all, it is concatenated!`
# 

echo "Collecting data from git repo..."

TMPDATA=$( mktemp __gnurfXXXXXXXXXXXXX.data )

# current directory, current commit: list all parents
date  '+Date:   %Y-%m-%d %H:%M:%S' > $TMPDATA
if test -f .CONTRIBUTORS.supplement ; then
	cat .CONTRIBUTORS.supplement >> $TMPDATA
fi
echo '----------------------' >> $TMPDATA
git rev-list HEAD | xargs git show --no-patch --pretty --date=short >> $TMPDATA


# https://stackoverflow.com/questions/7046381/multiline-syntax-for-piping-a-heredoc-is-this-portable
# https://tldp.org/LDP/abs/html/here-docs.html  ("Here documents create temporary files, but these files are deleted after opening and are not accessible to any other process.")
# https://nodejs.dev/learn/nodejs-streams
# https://github.com/nodejs/node-v0.x-archive/issues/7412  (bloody node still does take a bunch of code to read stdin: see node streams link above.)
# 
# Now this here is a nasty/clever way to feed node a temporary script with temporary data. hurr-di-hurr... >8-P
# 
# EDIT: pity: bash on Windows doesn't seem to support this:
#   cat <<EOF1 <<EOF2
#   first here-doc
#   EOF1
#   second here-doc
#   EOF2
# as it prints only the second heredoc. Bummer!
# 
# So we do it step by step (Node also doesn't like its script to be fed into it via heredoc: it doesn't show up as argv[] element!)

grep -E '^(Date|Author|commit|---------)' < $TMPDATA > $TMPDATA.b

cat <<EOS > $TMPDATA.js
// JS script...

console.error("Processing data from git repo...");

//console.error(process.argc, process.argv);

const fs = require('fs');

const datafilepath = process.argv[2];

let collabs_per_author = {};
let collabs_per_year = {};

let datum = {
	year: undefined, 
	quarter: undefined, 
	author: undefined, 
	email: undefined, 
	commit: []
};
let datum_fill = 0;

// incoming lines are always in the order: commit, author, date   or   date, author.
// OPTIONAL lines are: commit, date.

function push_datum(next_fill_bit) {
	if (datum_fill & next_fill_bit) {
		if (!datum.author) {
			console.error('DISCARD IMCOMPLETE: ', datum);
		}
		else {
			//console.error('PUSH: ', datum);
			let auth = datum.author;
			if (collabs_per_author[auth]) {
				collabs_per_author[auth].push(datum);
			}
			else {
				collabs_per_author[auth] = [ datum ];
			}

			let yr = datum.year;
			let q = datum.quarter;
			//let idx = yr * 4 + q;
			let idx = yr * 4;
			if (collabs_per_year[idx]) {
				collabs_per_year[idx].push(datum);
			}
			else {
				collabs_per_year[idx] = [ datum ];
			}
		}
		datum = {
			year: undefined, 
			quarter: undefined, 
			author: undefined, 
			email: undefined, 
			commit: []
		};
		datum_fill = 0;
	}
	datum_fill |= next_fill_bit;
}

let body = fs.readFileSync(datafilepath, 'utf8');
let a = body.split('\n').forEach((l) => {
	l = l.trim();
	if (!l.length)
		return;

	//console.error('line: ', l);
	let m = /^Date:\s+(\d+)-(\d+)-(\d+)/.exec(l);
	if (m) {
		//console.error('match: ', m);
		push_datum(0x01);

		datum.year = +m[1];
		datum.quarter = (+m[2] / 3) | 0;		// ~ int(month / 3)
		return;
	}
	m = /^Author:\s+(.+?)(?:<([^>]+)>)?$/.exec(l);
	if (m) {
		//console.error('match: ', m);
		push_datum(0x02);

		datum.author = m[1].trim();
		datum.email = (m[2] || "").trim();
		return;
	}
	m = /^commit:?\s+([\da-f]+)/i.exec(l);
	if (m) {
		//console.error('match: ', m);
		push_datum(0x04);

		datum.commit.push(m[1].trim());
		return;
	}
	// is this a sync line?
	m = /^-{9,}/.exec(l);
	if (m) {
		console.error('SYNC: ', m);
		// push what we have:
		push_datum(0xFF);
		datum_fill = 0;
		return;
	}

	console.error('NO MATCH: ', l);
});

// don't forget to flush/push the last record:
push_datum(0xFF);

//console.error({ collabs_per_author, collabs_per_year });

// summarize the results:
let summary_per_author = {};
let summary_per_year = {};

for (let auth in collabs_per_author) {
	let row = collabs_per_author[auth];
	datum = row[0];
	let year_start = datum.year;
	let year_end = datum.year;
	let commit_list = [];

	for (let idx in row) {
		datum = row[idx];
		year_start = Math.min(year_start, datum.year);
		year_end = Math.max(year_end, datum.year);
		commit_list.push(datum.commit);
	}

	summary_per_author[auth] = {
		author: auth,
		email: datum.email,
		year_start,
		year_end,
		commit_count: commit_list.length,
		commit_list
	};
}

for (let yi in collabs_per_year) {
	let row = collabs_per_year[yi];
	//console.error('year row', { yi, row });
	datum = row[0];
	let year = datum.year;
	let author_list = {};
	let commit_list = [];

	for (let idx in row) {
		datum = row[idx];
		author_list[datum.author] = datum;
		commit_list.push(datum.commit);
	}

	summary_per_year[yi] = {
		author_list,
		year,
		commit_count: commit_list.length,
		commit_list
	};
}

//console.error({ summary_per_author, summary_per_year });









function author_sort_order(a, b) {
  let nameA = a.toUpperCase(); // ignore upper and lowercase
  let nameB = b.toUpperCase(); // ignore upper and lowercase
  if (nameA < nameB) {
    return -1;
  }
  if (nameA > nameB) {
    return 1;
  }

  // names must be equal
  return 0;
}

function format_author(auth, mail) {
	// mangle email addresses a bit to thwart spam scrapers:
	mail = mail
		.replace(/\./g, ' dot ')
		.replace(/@/g, ' at ');
	//console.error('author mangled:', {auth, mail});		
	if (mail.length === 0)
		return auth;
	else
		return \`\${ auth } <\${ mail }>\`;
} 

function format_years(year_start, year_end) {
	if (year_start !== year_end) 
		return \` (\${year_start} – \${year_end}) \`;
	else 
		return \` (\${year_start}) \`;
} 

function format_contributions(commit_list) {
	return \` (\${ commit_list.length } commit\${ commit_list.length > 1 ? 's' : '' }) \`;
} 

function format_year(year) {
	return year;
} 

function format_authors(author_list) {
	let a = author_list.map((d) => {
		return format_author(d.author, d.email);
	});
	return '\n  * ' + a.sort(author_sort_order).join('\n  * ');
}












console.error("Generating CONTRIBUTORS.md file...");


console.log(\`

## Contributors

\`);

for (let auth of Object.keys(summary_per_author).sort(author_sort_order)) {
	datum = summary_per_author[auth];

	console.log(\`+ \${ format_author(datum.author, datum.email) } \${ format_years(datum.year_start, datum.year_end) } \${ format_contributions(datum.commit_list) }\`);
}


console.log(\`

## Over The Years

\`);

// sort years recent to old:
for (let yi of Object.keys(summary_per_year).sort((a, b) => b - a)) {
	datum = summary_per_year[yi];

	console.log(\`+ \${ format_year(datum.year) } 
\${ format_authors(Object.values(datum.author_list)) }
	\`);
}


EOS

if test -f .CONTRIBUTORS.prelude ; then
	cat .CONTRIBUTORS.prelude > CONTRIBUTORS.md
else
	rm -f CONTRIBUTORS.md
fi
node $TMPDATA.js $TMPDATA.b >> CONTRIBUTORS.md
