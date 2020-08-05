const core = require('@actions/core');

class Config {
    constructor()
    {
        this.path = '';
        this.destination = '';
        this.client_id = '';
        this.client_secret = '';
        this.username = '';
        this.password = '';
        this.subdomain = '';
        this.application_control_plane = '';
    }
}

module.exports = {

    Config: Config,

    loadConfigFromInputs: function() {
        cfg = new Config;
        cfg.path = core.getInput("path");
        cfg.destination = core.getInput("destination");
        cfg.client_id = core.getInput("client-id");
        cfg.client_secret = core.getInput("client-secret");
        cfg.username = core.getInput("username");
        cfg.password = core.getInput("password");
        cfg.subdomain = core.getInput("subdomain");
        cfg.application_control_plane = core.getInput("application-control-plane");
        return cfg;
    }
}
