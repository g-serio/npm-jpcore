#!/usr/bin/env node
import { Command } from 'commander';
import chalk from 'chalk';
import fs from 'fs-extra';
import path from 'path';
import { execa } from 'execa';
import ora from 'ora';
import { fileURLToPath } from 'url';
import os from 'os';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const CLI_ASSETS_DIR = path.resolve(__dirname, '../assets');
const TEMPLATES_DIR = path.join(CLI_ASSETS_DIR, 'templates');
const LEGACY_ALPHA_DNA_PATH = path.join(CLI_ASSETS_DIR, 'src_tenant_alpha.sh');
const PACKAGE_JSON_PATH = path.resolve(__dirname, '../package.json');
const CLI_PACKAGE = JSON.parse(await fs.readFile(PACKAGE_JSON_PATH, 'utf-8'));

const program = new Command();

program
  .name('olonjs')
  .description('OlonJS CLI - Sovereign Projection Engine')
  .version(CLI_PACKAGE.version);

const invokedAs = path.basename(process.argv[1] ?? '');
if (invokedAs === 'jsonpages' || invokedAs === 'jsonpages.cmd') {
  console.warn(chalk.yellow('[compat] `jsonpages` is deprecated. Use `olonjs` instead.'));
}

async function processScriptInNode(scriptPath, targetDir) {
  const content = await fs.readFile(scriptPath, 'utf-8');
  const lines = content.split('\n');

  let captureMode = false;
  let delimiter = '';
  let currentFile = '';
  let fileBuffer = [];

  for (const line of lines) {
    const trimmed = line.trim();

    if (captureMode) {
      if (trimmed === delimiter) {
        const filePath = path.join(targetDir, currentFile);
        await fs.outputFile(filePath, fileBuffer.join('\n'));
        captureMode = false;
        fileBuffer = [];
      } else {
        fileBuffer.push(line);
      }
      continue;
    }

    if (trimmed.startsWith('mkdir -p')) {
      const match = trimmed.match(/"([^"]+)"/) || trimmed.match(/\s+([^\s]+)/);
      const dirPath = match ? match[1].replace(/"/g, '') : null;
      if (dirPath) {
        await fs.ensureDir(path.join(targetDir, dirPath));
      }
    } else if (trimmed.startsWith('cat <<')) {
      const match = trimmed.match(/<<\s*'([^']+)'\s*>\s*"([^"]+)"/);
      if (match) {
        delimiter = match[1];
        currentFile = match[2];
        captureMode = true;
      }
    }
  }
}

function getAvailableTemplates() {
  if (!fs.existsSync(TEMPLATES_DIR)) return [];
  return fs
    .readdirSync(TEMPLATES_DIR, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .filter((name) => fs.existsSync(path.join(TEMPLATES_DIR, name, 'src_tenant.sh')))
    .sort((a, b) => a.localeCompare(b));
}

function resolveTemplateScriptPath(templateName) {
  const templatePath = path.join(TEMPLATES_DIR, templateName, 'src_tenant.sh');
  if (fs.existsSync(templatePath)) return templatePath;
  if (templateName === 'alpha' && fs.existsSync(LEGACY_ALPHA_DNA_PATH)) return LEGACY_ALPHA_DNA_PATH;
  return templatePath;
}

program
  .command('new')
  .argument('<type>', 'Type of artifact (tenant)')
  .argument('<name>', 'Name of the new tenant')
  .option('--template <name>', 'Template profile (default: alpha)', 'alpha')
  .option('--script <path>', 'Override default deterministic script path')
  .action(async (type, name, options) => {
    if (type !== 'tenant') {
      console.log(chalk.red('Error: Only "tenant" type is supported.'));
      return;
    }

    const targetDir = path.join(process.cwd(), name);
    const availableTemplates = getAvailableTemplates();
    const template = options.template;
    const scriptPath = options.script
      ? path.resolve(process.cwd(), options.script)
      : resolveTemplateScriptPath(template);

    if (!options.script && !availableTemplates.includes(template) && !(template === 'alpha' && fs.existsSync(LEGACY_ALPHA_DNA_PATH))) {
      console.log(chalk.red(`Error: Unknown template "${template}".`));
      console.log(chalk.yellow(`Available templates: ${availableTemplates.length ? availableTemplates.join(', ') : '(none found)'}`));
      return;
    }

    if (!fs.existsSync(scriptPath)) {
      console.log(chalk.red(`Error: DNA script not found at ${scriptPath}`));
      console.log(chalk.yellow(`Debug info: template=${template}, assets=${CLI_ASSETS_DIR}`));
      return;
    }

    console.log(chalk.blue.bold(`\nProjecting Sovereign Tenant: ${name} (template: ${template})\n`));
    const spinner = ora();

    try {
      spinner.start('Setting up environment (Vite + TS)...');
      await fs.ensureDir(targetDir);

      const npmCmd = process.platform === 'win32' ? 'npm.cmd' : 'npm';
      await execa(npmCmd, ['create', 'vite@latest', '.', '--', '--template', 'react-ts'], { cwd: targetDir });
      spinner.succeed('Environment scaffolded.');

      spinner.start('Wiping default boilerplate...');
      await fs.emptyDir(path.join(targetDir, 'src'));
      const junk = ['App.css', 'App.tsx', 'main.tsx', 'vite-env.d.ts', 'favicon.ico', 'index.html'];
      for (const file of junk) {
        await fs.remove(path.join(targetDir, file)).catch(() => {});
        await fs.remove(path.join(targetDir, 'src', file)).catch(() => {});
      }
      spinner.succeed('Clean slate achieved.');

      spinner.start('Injecting Sovereign Configurations...');
      await injectInfraFiles(targetDir, name);
      spinner.succeed('Infrastructure configured.');

      spinner.start('Executing deterministic src projection...');
      await processScriptInNode(scriptPath, targetDir);
      spinner.succeed('Source code and assets projected successfully.');

      spinner.start('Installing dependencies (this may take a minute)...');
      await execa(npmCmd, ['install'], { cwd: targetDir });
      spinner.succeed(chalk.green.bold('Tenant Ready.'));

      console.log(`\n${chalk.white.bgBlue(' NEXT STEPS ')}`);
      console.log(`  ${chalk.cyan(`cd ${name}`)}`);
      console.log(`  ${chalk.cyan('npm run dev')}   <- Start development`);
      console.log(`  ${chalk.cyan('npm run build')} <- Validate Green Build`);
      console.log(`\nTemplate used: ${template}\n`);
    } catch (error) {
      spinner.fail(chalk.red('Projection failed.'));
      console.error(error);
    }
  });

async function injectInfraFiles(targetDir, name) {
  const pkg = {
    name,
    private: true,
    version: '1.0.0',
    type: 'module',
    scripts: {
      dev: 'vite',
      build: 'tsc && vite build',
      preview: 'vite preview',
    },
  };
  await fs.writeJson(path.join(targetDir, 'package.json'), pkg, { spaces: 2 });

  await fs.ensureDir(path.join(targetDir, 'public', 'assets', 'images'));
  await fs.ensureDir(path.join(targetDir, 'src', 'data', 'config'));
  await fs.ensureDir(path.join(targetDir, 'src', 'data', 'pages'));

  const tsConfig = `
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"]
}`;
  await fs.writeFile(path.join(targetDir, 'tsconfig.json'), tsConfig.trim());

  const shadcnConfig = {
    $schema: 'https://ui.shadcn.com/schema.json',
    style: 'radix-nova',
    rsc: false,
    tsx: true,
    tailwind: {
      config: '',
      css: 'src/index.css',
      baseColor: 'zinc',
      cssVariables: true,
      prefix: '',
    },
    aliases: {
      components: '@/components',
      utils: '@/lib/utils',
      ui: '@/components/ui',
      lib: '@/lib',
      hooks: '@/hooks',
    },
  };
  await fs.writeJson(path.join(targetDir, 'components.json'), shadcnConfig, { spaces: 2 });
}

program
  .command('init-mcp')
  .description('Automatically configure Cursor MCP settings for OlonJS')
  .action(async () => {
    console.log(chalk.blue.bold('\nInitializing OlonJS MCP for Cursor...\n'));
    
    const isWin = process.platform === 'win32';
    const commandName = isWin ? 'npx.cmd' : 'npx';
    
    const mcpConfig = {
      command: commandName,
      args: ['-y', '@olonjs/mcp@latest', 'http://localhost:5174']
    };

    const homeDir = os.homedir();
    const pathsToCheck = [
      path.join(homeDir, '.cursor', 'mcp.json'),
    ];

    if (isWin) {
      pathsToCheck.push(path.join(homeDir, 'AppData', 'Roaming', 'Cursor', 'User', 'globalStorage', 'saoudrizwan.claude-dev', 'settings', 'cline_mcp_settings.json'));
    } else if (process.platform === 'darwin') {
      pathsToCheck.push(path.join(homeDir, 'Library', 'Application Support', 'Cursor', 'User', 'globalStorage', 'saoudrizwan.claude-dev', 'settings', 'cline_mcp_settings.json'));
    } else {
      pathsToCheck.push(path.join(homeDir, '.config', 'Cursor', 'User', 'globalStorage', 'saoudrizwan.claude-dev', 'settings', 'cline_mcp_settings.json'));
    }

    let updatedCount = 0;

    for (const configPath of pathsToCheck) {
      try {
        let configData = { mcpServers: {} };
        
        if (fs.existsSync(configPath)) {
          const content = await fs.readFile(configPath, 'utf-8');
          try {
            configData = JSON.parse(content);
          } catch (e) {
            console.log(chalk.yellow(`Warning: Could not parse ${configPath}. Creating new object.`));
          }
        } else {
          // If the file doesn't exist, we ensure the directory exists first
          await fs.ensureDir(path.dirname(configPath));
        }

        if (!configData.mcpServers) {
          configData.mcpServers = {};
        }

        configData.mcpServers['OlonJS'] = mcpConfig;

        await fs.writeFile(configPath, JSON.stringify(configData, null, 2));
        console.log(chalk.green(`✓ Updated MCP configuration at: ${configPath}`));
        updatedCount++;
      } catch (err) {
        console.log(chalk.gray(`Skipped ${configPath} (not found or accessible)`));
      }
    }

    if (updatedCount === 0) {
      console.log(chalk.red('\nCould not find any Cursor MCP configuration files to update.'));
      console.log('You can manually add the following JSON to your MCP settings:');
      console.log(JSON.stringify({ "OlonJS": mcpConfig }, null, 2));
    } else {
      console.log(chalk.green.bold('\nOlonJS MCP configured successfully!'));
      console.log(chalk.cyan('Please restart Cursor (or run "Developer: Reload Window") to apply the changes.'));
    }
  });

program.parse();
