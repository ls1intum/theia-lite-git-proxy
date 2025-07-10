# @isomorphic-git/cors-proxy

## Helm Deployment

This repository includes a Helm chart for easy deployment to Kubernetes clusters. The chart is located in the `helm/git-proxy` directory.

### Quick Start

1. Configure your values:

   ```bash
   # Copy the default values file
   cp helm/git-proxy/values.yaml my-values.yaml
   ```

2. Edit `my-values.yaml` to set your configuration:

   ```yaml
   image:
     repository: ghcr.io/ls1intum/theia-lite-git-proxy
     tag: "latest"
     pullPolicy: Always

   ingress:
     enabled: true
     className: "nginx"
     annotations:
       kubernetes.io/ingress.class: "nginx"
       cert-manager.io/cluster-issuer: "letsencrypt-prod"
     hosts:
       - host: git-proxy.theia.artemis.cit.tum.de
         paths:
           - path: /
             pathType: Prefix
     tls:
       - secretName: git-proxy-tls
         hosts:
           - git-proxy.theia.artemis.cit.tum.de
   ```

3. Deploy the chart:

   ```bash
   helm upgrade --install --create-namespace --namepsace git-proxy git-proxy ./helm/git-proxy 
   ```

### Configuration Options

Key parameters in `values.yaml`:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Image repository | `ghcr.io/ls1intum/theia-lite-git-proxy` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class name | `nginx` |
| `ingress.annotations` | Ingress annotations | See values.yaml for defaults |
| `service.port` | Service port | `80` |
| `service.targetPort` | Container port | `9999` |
| `resources.limits` | Resource limits | `cpu: 500m, memory: 512Mi` |
| `resources.requests` | Resource requests | `cpu: 100m, memory: 128Mi` |

---

This is the software running on [cors.isomorphic-git.org](https://cors.isomorphic-git.org/) -
a free service (generously sponsored by [Clever Cloud](https://www.clever-cloud.com/?utm_source=ref&utm_medium=link&utm_campaign=isomorphic-git))
for users of [isomorphic-git](https://isomorphic-git.org) that enables cloning and pushing repos in the browser.

It is derived from [cors-buster](https://github.com/wmhilton/cors-buster) with added restrictions to reduce the opportunity to abuse the proxy.
Namely, it blocks requests that don't look like valid git requests.

## Installation

```sh
npm install @isomorphic-git/cors-proxy
```

## CLI usage

Start proxy on default port 9999:

```sh
cors-proxy start
```

Start proxy on a custom port:

```sh
cors-proxy start -p 9889
```

Start proxy in daemon mode. It will write the PID of the daemon process to `$PWD/cors-proxy.pid`:

```sh
cors-proxy start -d
```

Kill the process with the PID specified in `$PWD/cors-proxy.pid`:

```sh
cors-proxy stop
```

### CLI configuration

Environment variables:
- `PORT` the port to listen to (if run with `npm start`)
- `ALLOW_ORIGIN` the value for the 'Access-Control-Allow-Origin' CORS header
- `INSECURE_HTTP_ORIGINS` comma separated list of origins for which HTTP should be used instead of HTTPS (added to make developing against locally running git servers easier)


## Middleware usage

You can also use the `cors-proxy` as a middleware in your own server.

```js
const express = require('express')
const corsProxy = require('@isomorphic-git/cors-proxy/middleware.js')

const app = express()
const options = {}

app.use(corsProxy(options))

```

### Middleware configuration

*The middleware doesn't use the environment variables.* The options object supports the following properties:

- `origin`: _string_. The value for the 'Access-Control-Allow-Origin' CORS header
- `insecure_origins`: _string[]_. Array of origins for which HTTP should be used instead of HTTPS (added to make developing against locally running git servers easier)
- `authorization`: _(req, res, next) => void_. A middleware function you can use to handle custom authorization. Is run after filtering for git-like requests and handling CORS but before the request is proxied.

_Example:_
```ts
app.use(
  corsProxy({
    authorization: (req: Request, res: Response, next: NextFunction) => {
      // proxied git HTTP requests already use the Authorization header for git credentials,
      // so their [Company] credentials are inserted in the X-Authorization header instead.
      if (getAuthorizedUser(req, 'X-Authorization')) {
        return next();
      } else {
        return res.status(401).send("Unable to authenticate you with [Company]'s git proxy");
      }
    },
  })
);

// Only requests with a valid JSON Web Token will be proxied
function getAuthorizedUser(req: Request, header: string = 'Authorization') {
  const Authorization = req.get(header);

  if (Authorization) {
    const token = Authorization.replace('Bearer ', '');
    try {
      const verifiedToken = verify(token, env.APP_SECRET) as IToken;
      if (verifiedToken) {
        return {
          id: verifiedToken.userId,
        };
      }
    } catch (e) {
      // noop
    }
  }
}
```

## Installation on Kubernetes

There is no official chart for this project, helm or otherwise. You can make your own, but keep in mind cors-proxy uses the Micro server, which will return a 403 error for any requests that do not have the user agent header.

_Example:_
```yaml
  containers:
      - name: cors-proxy
        image: node:lts-alpine
        env:
        - name: ALLOW_ORIGIN
          value: https://mydomain.com
        command:
        - npx
        args:
        - '@isomorphic-git/cors-proxy'
        - start
        ports:
        - containerPort: 9999
          hostPort: 9999
          name: proxy
          protocol: TCP
        livenessProbe:
          tcpSocket:
            port: proxy
        readinessProbe:
          tcpSocket:
            port: proxy
```

## License

This work is released under [The MIT License](https://opensource.org/licenses/MIT)
