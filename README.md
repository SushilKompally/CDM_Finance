Welcome to your new dbt project!

### Using the starter project

Try running the following commands:
- dbt run
- dbt test


### Resources:
- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [dbt community](https://getdbt.com/community) to learn from other analytics engineers
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices


### Deployment
- When deploying a versioned commit, perform the following:
git tag v1.0.4  (change to the latest version based on what is deployed in the registry)
git rev-list -1 v1.0.2 (Validate the tag is on the same commit as the latest change)
git push origin [branch] --tags   