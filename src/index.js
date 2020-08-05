const core = require('@actions/core');
const github = require('@actions/github');
const exec = require('@actions/exec');
const io = require('@actions/io');
const pathlib = require('path');
const glob = require('@actions/glob');
const fs = require('fs');
const cfg = require("./config");

function walk(dir) {
    function _walk(dir, fileList) 
    {
        const files = fs.readdirSync(dir);
        for (const file of files) 
        {
            const path = pathlib.join(dir, file);
            const stat = fs.lstatSync(path);
            if (stat.isDirectory()) 
            {
                fileList = _walk(path, fileList);
            } 
            else 
            {
                fileList.push(path);
            }
        }
        return fileList;
    }
    return _walk(dir, []);
}

async function run(config)
{
    core.setSecret(config.client_id);
    core.setSecret(config.client_secret);
    core.setSecret(config.username);
    core.setSecret(config.password);
    core.setSecret(config.subdomain);

    const powershellPath = await io.which('powershell', true);
    let escapedScript = pathlib
        .join(__dirname, '..', 'Upload-Sharefile.ps1')
        .replace(/'/g, "''");

    const globber = await glob.create(config.path);
    const results = await globber.glob();
    const filesToUpload = [];
    for (const path of results)
    {
        const stat = fs.lstatSync(path);
        if (!stat.isDirectory()) 
        {
            filesToUpload.push('"'+path+'"');
        }
    }

    const filesToUploadPwshList = "@(" + filesToUpload.join(';') + ")";

    let command = `& '${escapedScript}'\
     -ClientID '${config.client_id}'\
     -ClientSecret '${config.client_secret}'\
     -Username '${config.username}'\
     -Password '${config.password}'\
     -Subdomain '${config.subdomain}'\
     -ApplicationControlPlane '${config.application_control_plane}'\
     -ShareParentFolderLink\
     -DestinationDirectory '${config.destination}'\
     -Files ${filesToUploadPwshList}`;

    let output = '';

    const options = {};
    options.listeners = {
        stdout: function(data) {
            output += data.toString();
        },
        stderr: function(data) {
            output += data.toString();
        }
    }

    const resultCode = await exec.exec(
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

    if (resultCode === 0) {
        core.setOutput('share-url', output.trim());
    }
    else {
        core.setFailed(`Upload to ShareFile failed with exit code ${resultCode}.`);
    }
}

const config = cfg.loadConfigFromInputs();
run(config);
