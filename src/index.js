const core = require('@actions/core');
const github = require('@actions/github');
const exec = require('@actions/exec');
const io = require('@actions/io');
const pathlib = require('path');
const fs = require('fs');
const cfg = require("./config");

const IS_WINDOWS = process.platform === 'win32'

function processPath(patterns)
{
    const result = [];
    if (IS_WINDOWS) 
    {
        patterns = patterns.replace(/\r\n/g, '\n')
        patterns = patterns.replace(/\r/g, '\n')
    }
    const lines = patterns.split('\n').map(x => x.trim())
    for (const line of lines) {
      // Empty or comment
      if (!line || line.startsWith('#')) {
        continue
      }
      // Pattern
      else {
        result.push(line)
      }
    }
    return result;
}

function formatAsPowershellList(stringArg)
{
    var asList = processPath(stringArg);
    var quoted = asList.map(x => `"${x}"`);
    return "@(" + quoted.join(';') + ")";
}

async function run(config)
{
    core.setSecret(config.client_id);
    core.setSecret(config.client_secret);
    core.setSecret(config.username);
    core.setSecret(config.password);

    const powershellPath = await io.which('powershell', true);
    let escapedScript = pathlib
        .join(__dirname, '..', 'Upload-Sharefile.ps1')
        .replace(/'/g, "''");

    const filesToUploadPwshList = formatAsPowershellList(config.path);
    const filesToExcludePwshList = formatAsPowershellList(config.exclude || "");

    if (config.application_control_plane === "") {
        config.application_control_plane = "sharefile.com";
    }

    if (config.timeout === "") {
        config.timeout = 120000;
    }

    let command = `& '${escapedScript}'\
     -ClientID '${config.client_id}'\
     -ClientSecret '${config.client_secret}'\
     -Username '${config.username}'\
     -Password '${config.password}'\
     -Subdomain '${config.subdomain}'\
     -ApplicationControlPlane '${config.application_control_plane}'\
     -ShareParentFolderLink\
     -DestinationDirectory '${config.destination}'\
     -Timeout ${config.timeout}\
     -Files ${filesToUploadPwshList}\
     -Exclude ${filesToExcludePwshList}\
     -ErrorAction Stop`;

    let output = '';

    const options = {};
    options.listeners = {
        stdout: function(data) {
            output += data.toString();
        }
    }

    let resultCode = 0;
    let processError = null;
    
    try
    {
        resultCode = await exec.exec(
            `"${powershellPath}"`,
            [
                '-NoLogo',
                '-Sta',
                '-NoProfile',
                '-NonInteractive',
                '-ExecutionPolicy',
                'Unrestricted',
                '-Command',
                command
            ],
            options
        );
    }
    catch (error)
    {
        processError = error;
    }

    if (processError) {
        core.setFailed(processError);
    }
    else {
        core.setOutput('share-url', output.trim());
    }
}

const config = cfg.loadConfigFromInputs();
run(config);
