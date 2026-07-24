import readline from 'node:readline';

/**
 * Minimal arrow-key select (no extra deps).
 * @param {string} message
 * @param {Array<{ label: string, value: string }>} choices
 * @returns {Promise<string>} selected value
 */
export async function selectWithArrows(message, choices) {
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    throw new Error('Interactive template selection requires a TTY. Pass --template next|vite|alpha.');
  }

  let index = 0;

  const render = () => {
    const lines = choices.map((choice, i) => {
      const mark = i === index ? '>' : ' ';
      return `  ${mark} ${choice.label}`;
    });
    process.stdout.write(`\x1B[?25l${message}\n${lines.join('\n')}\n`);
  };

  const clear = () => {
    const lineCount = choices.length + 1;
    process.stdout.write(`\x1B[${lineCount}A\x1B[0J`);
  };

  render();

  return new Promise((resolve, reject) => {
    readline.emitKeypressEvents(process.stdin);
    process.stdin.setRawMode(true);
    process.stdin.resume();

    const onKey = (_str, key) => {
      if (!key) return;
      if (key.ctrl && key.name === 'c') {
        cleanup();
        reject(new Error('Cancelled'));
        return;
      }
      if (key.name === 'up' || key.name === 'k') {
        index = (index - 1 + choices.length) % choices.length;
        clear();
        render();
        return;
      }
      if (key.name === 'down' || key.name === 'j') {
        index = (index + 1) % choices.length;
        clear();
        render();
        return;
      }
      if (key.name === 'return') {
        cleanup();
        process.stdout.write(`\x1B[?25h`);
        resolve(choices[index].value);
      }
    };

    function cleanup() {
      process.stdin.setRawMode(false);
      process.stdin.pause();
      process.stdin.off('keypress', onKey);
      process.stdout.write('\x1B[?25h');
    }

    process.stdin.on('keypress', onKey);
  });
}
