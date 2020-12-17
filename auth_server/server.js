require('dotenv').config();
const express = require('express')
const session = require('express-session');
const LowdbStore = require('lowdb-session-store')(session);
const lowdb = require('lowdb');
const FileSync = require('lowdb/adapters/FileSync');
const crypto = require('crypto');
const https = require('https');

const adapter = new FileSync('./sessions.json', { defaultValue: [] });
const db = lowdb(adapter);

const app = express()
const port = process.env.PORT || 3000;

const PROD = process.env.NODE_ENV === 'production';

app.use(session({
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: true,
    cookie: { secure: PROD },
    store: new LowdbStore(db, {
        ttl: 86400
    })
}));


app.get('/')

app.get('/github', (req, res) => {
    req.session.redirect_url = req.query.redirect_url;
    req.session.state = randomSecure();
    const params = new URLSearchParams({
        client_id: process.env.GITHUB_CLIENT_ID,
        scope: 'gist',
        state: req.session.state
    }).toString();
    res.redirect(`https://github.com/login/oauth/authorize?${params}`);
});

app.get('/callback/github', (req, res) => {
    const { code, state } = req.query;
    if(!code || !state) {
        res.status(400).send('ERROR: There was an error authenticating with GitHub for Pluto.jl');
        return;
    }

    // This means there is no longer a session containing a valid state, which is used to present XSF attacks
    if(!req.session.state) {
        res.status(400).send('ERROR: Your session has likely expired. Please try to re-authenticate from Pluto.jl');
        return;
    }

    const postData = new URLSearchParams({
        client_id: process.env.GITHUB_CLIENT_ID,
        client_secret: process.env.GITHUB_SECRET,
        code,
        state: req.session.state
    }).toString();
    const options = {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Content-Length': Buffer.byteLength(postData),
            'Accept': 'application/json'
        }
    };
    const ghReq = https.request('https://github.com/login/oauth/access_token', options, resp => {
        let ghRes = '';
        resp.on('data', (chunk) => {
            ghRes += chunk;
        });
        resp.on('end', () => {
            const parsedRes = JSON.parse(ghRes);
            if(!parsedRes.access_token) {
                res.status(400).send('ERROR: No access token was provided by GitHub');
                return;
            }
            res.redirect((req.session.redirect_url || 'http://localhost:1234/auth/github') + '?token=' + parsedRes.access_token);
        });
    });
    ghReq.write(postData);
    ghReq.end();
});


// Development endpoints - SHOULD NOT BE EXPOSED IN PRODUCTION
if(!PROD) {
    app.get('/_session', (req, res) => {
        res.json(req.session);
    });
}

app.listen(port, () => {
    console.log(`Pluto.jl authentication server listening on port ${port}`)
});


function randomSecure(bytes=64) {
    return crypto.randomBytes(64).toString('base64');
}
