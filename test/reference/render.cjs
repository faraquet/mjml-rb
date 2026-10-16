const mjml = require('mjml');
const readline = require('node:readline');
const version = require('mjml/package.json').version;
if (version !== '5.4.1') throw new Error(`Expected mjml@5.4.1, found ${version}`);
(async () => {
  for await (const line of readline.createInterface({ input: process.stdin })) {
    try {
      const { source, options = {} } = JSON.parse(line);
      const result = await mjml(source, options);
      process.stdout.write(JSON.stringify({ html: result.html, errors: result.errors }) + '\n');
    } catch (error) {
      process.stdout.write(JSON.stringify({ html: '', errors: error.errors || [{ message: error.message }] }) + '\n');
    }
  }
})();
